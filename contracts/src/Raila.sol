// SPDX-License-Identifier: MIT

pragma solidity ^0.8;

import {UD60x18, powu} from "@prb-math/src/UD60x18.sol";
import {IProofOfHumanity} from "./IProofOfHumanity.sol";
import {IERC20} from "@openzeppelin-contracts/interfaces/IERC20.sol";
import {IERC721} from "@openzeppelin-contracts/interfaces/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin-contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721Receiver} from "@openzeppelin-contracts/interfaces/IERC721Receiver.sol";
import {Base64} from "@openzeppelin-contracts/utils/Base64.sol";
import "forge-std/console.sol";

/// @title Raila
contract Raila is IERC721, IERC721Metadata {
    enum RequestStatus {
        Open,
        Loan
    }

    struct Request {
        // 1st slot: 48 bits remaining
        bytes20 debtor; // humanityId of the debtor
        uint40 createdAtBlock; // supports subgraph-free interfaces by reading event at block
        RequestStatus status;
        // 2nd slot: 0 bits remaining
        address creditor; // paying the loan directs the money to creditor. creditor is transferrable.
        uint40 fundedAt; // for nft vanity
        uint40 lastUpdatedAt; // used to calculate accrued interest
        uint16 feeRate; // fee rate at the time Loan is accepted
        // 3rd slot
        UD60x18 interestRatePerSecond; // offered by the borrower (potential ux issue? frontend could guide)
        // 4th slot
        uint256 originalDebt; // if Open, requested amount. if Loan, remaining from original
        // 5th slot
        uint256 totalDebt;
        // 6th slot
        uint256 defaultThreshold;
    }

    event RequestCreation(
        bytes20 indexed debtor, uint256 indexed requestId, string requestMetadata
    );
    event RequestCanceled(uint256 indexed requestId);
    // there is no need for "LoanAccepted", you can filter for erc721 Transfer(0, ?, requestId) to see mint.
    event LoanRepayment(uint256 indexed requestId, uint256 repaidAmount, uint256 pendingDebt);
    event LoanForgiven(uint256 indexed requestId, uint256 pendingDebt);
    // there is no need for "LoanClosed", you can filter for erc721 Transfer(?, 0, requestId) to see burn.

    error ERC721InvalidReceiver(address receiver);

    uint256 internal constant ONE = 1000000000000000000;

    IERC20 public immutable USD;
    IProofOfHumanity public immutable PROOF_OF_HUMANITY;

    // at the very least, to be paid in full, loans will pay x days of interest.
    // that way creditor is guaranteed to be paid, if loan is eventually paid, some interest.
    uint256 public MINIMUM_INTEREST_PERIOD;

    // protect borrowers from eternal debt with a sensible max rate
    UD60x18 public MAXIMUM_INTEREST_RATE;

    // basis points. fees are only paid after the initial loan is covered.
    // fees are sent to raila treasury (maintenance, bounties, server costs...)
    uint16 public FEE_RATE;

    address public TREASURY;
    address public GOVERNOR;

    mapping(bytes20 => uint256) public borrowerToRequestId;
    mapping(uint256 => Request) public requests;
    mapping(address => uint256) public balanceOf; // for erc721 balanceOf
    mapping(uint256 => address) public getApproved; // for erc721 getApproveds
    mapping(address => mapping(address => bool)) public isApprovedForAll; //for erc721 isApprovedForAll
    uint256 public lastRequestId;

    constructor(
        address _governor,
        address _treasury,
        uint256 _minimumInterestPeriod,
        UD60x18 _maxInterestRate,
        IERC20 _usdToken,
        IProofOfHumanity _poh,
        uint16 _feeRate
    ) {
        GOVERNOR = _governor;
        TREASURY = _treasury;
        MINIMUM_INTEREST_PERIOD = _minimumInterestPeriod;
        MAXIMUM_INTEREST_RATE = _maxInterestRate;
        USD = IERC20(_usdToken);
        PROOF_OF_HUMANITY = IProofOfHumanity(_poh);
        FEE_RATE = _feeRate;
    }

    function createRequest(
        uint256 loanAmount,
        UD60x18 interestRatePerSecond,
        uint256 defaultThreshold,
        string calldata requestMetadata
    ) external returns (uint256) {
        bytes20 humanityId = PROOF_OF_HUMANITY.humanityOf(msg.sender);
        require(humanityId != bytes20(0));
        uint256 requestId = borrowerToRequestId[humanityId];
        require(requestId == 0);
        uint256 startingDebt = interestHelper(
            loanAmount, interestRatePerSecond, MINIMUM_INTEREST_PERIOD
        );
        require(startingDebt < defaultThreshold);
        require(
            UD60x18.wrap(1 ether) < interestRatePerSecond
            && interestRatePerSecond < MAXIMUM_INTEREST_RATE
        );
        // create request
        lastRequestId++; // the first request will have id 1
        Request storage request = requests[lastRequestId];
        request.debtor = humanityId;
        request.createdAtBlock = uint40(block.number);
        // request.status is already RequestStatus.Open;
        request.interestRatePerSecond = interestRatePerSecond;
        request.originalDebt = loanAmount;
        request.defaultThreshold = defaultThreshold;
        // feeRate is set when created
        borrowerToRequestId[humanityId] = lastRequestId;
        emit RequestCreation(humanityId, lastRequestId, requestMetadata);
        return lastRequestId;
    }

    function cancelRequest() external {
        bytes20 humanityId = PROOF_OF_HUMANITY.humanityOf(msg.sender);
        uint256 requestId = borrowerToRequestId[humanityId];
        require(requestId != 0); // has nothing to cancel
        Request storage request = requests[lastRequestId];
        require(request.status == RequestStatus.Open);
        // close request
        borrowerToRequestId[humanityId] = 0;
        delete requests[requestId];
        emit RequestCanceled(requestId);
    }

    function acceptRequest(uint256 requestId) external {
        Request storage request = requests[requestId];
        require(request.status == RequestStatus.Open);
        address boundDebtor = PROOF_OF_HUMANITY.boundTo(request.debtor);
        require(boundDebtor != address(0)); // ensure still human
        require(USD.transferFrom(msg.sender, boundDebtor, request.originalDebt));
        // loan request was accepted, and into the debtor
        request.status = RequestStatus.Loan;
        request.creditor = msg.sender;
        request.fundedAt = uint40(block.timestamp);
        request.feeRate = FEE_RATE;
        // to ensure a minimum amount of interest is paid,
        // we initially advance the lastUpdatedAt timestamp by the minimum period.
        // and we set the totalDebt to be originalDebt + those interests.
        request.lastUpdatedAt = uint40(block.timestamp + MINIMUM_INTEREST_PERIOD);
        request.totalDebt = interestHelper(request.originalDebt, request.interestRatePerSecond, MINIMUM_INTEREST_PERIOD);
        // erc721 mint
        balanceOf[msg.sender]++;
        emit Transfer(address(0), msg.sender, requestId);
    }

    function payLoan(uint256 requestId, uint256 amount) external {
        Request storage request = requests[requestId];
        require(request.status == RequestStatus.Loan);
        require(USD.transferFrom(msg.sender, address(this), amount));
        // first update the debt
        // if minimum period has not passed yet, do not update it
        if (block.timestamp > request.lastUpdatedAt) {
            request.totalDebt = interestHelper(
                request.totalDebt, request.interestRatePerSecond, block.timestamp - uint256(request.lastUpdatedAt)
            );
            request.lastUpdatedAt = uint40(block.timestamp);
        }
        // from here, there are three payment steps to consider: original, total, reimburse.
        // a buffer will be used to store the remainder between steps.
        uint256 amountBuffer = amount;
        uint256 toCreditor;
        uint256 toTreasury;
        if (request.originalDebt > 0) {
            console.log("theres og debt");
            console.log("amb", amountBuffer, "ogd", request.originalDebt);
            // if there is original debt pending, pay towards it.
            uint256 deductionToOriginalDebt = amountBuffer > request.originalDebt ? request.originalDebt : amountBuffer;
            request.originalDebt = request.originalDebt - deductionToOriginalDebt;
            request.totalDebt = request.totalDebt - deductionToOriginalDebt;
            // creditors recieve original debt without fees, while it lasts.
            toCreditor = deductionToOriginalDebt;
            amountBuffer = amountBuffer - deductionToOriginalDebt;
        }
        console.log("handled og debt, pending tot:", request.totalDebt, "buffer", amountBuffer);

        if (amountBuffer > 0) {
            console.log("theres tot debt");
            console.log("amb", amountBuffer, "totd", request.totalDebt);
            uint256 deductionToTotalDebt = amountBuffer > request.totalDebt ? request.totalDebt : amountBuffer;

            request.totalDebt = request.totalDebt - deductionToTotalDebt;
            console.log("final tot", request.totalDebt);
            // regular debt directs some of the money as fees to treasury
            toTreasury = deductionToTotalDebt * request.feeRate / 10_000;
            console.log("fee", toTreasury);
            toCreditor += deductionToTotalDebt - toTreasury;
            console.log("creditorAmount", deductionToTotalDebt - toTreasury, "toCreditor", toCreditor);
            amountBuffer = amountBuffer - deductionToTotalDebt;
        }

        // now, amountBuffer is whatever is left after covering both debt types.
        // consider it may be be greater than zero for this event, and for refunding the sender.
        emit LoanRepayment(requestId, amount - amountBuffer, request.totalDebt);

        console.log("FINAL bookkeeping; totalPaid", amount - amountBuffer, "excess", amountBuffer);
        console.log("toCreditor", toCreditor, "toTreasury", toTreasury);
        // after accounting for changes, we finally pay
        if (toCreditor > 0) USD.transfer(request.creditor, toCreditor);
        if (toTreasury > 0) USD.transfer(TREASURY, toTreasury);
        if (amountBuffer > 0) USD.transfer(msg.sender, amountBuffer);
        
        // if total debt becomes zero, close it and emit events.
        if (request.totalDebt == 0) {
            _burn(requestId);
        }
    }

    function forgiveDebt(uint256 requestId) external {
        // todo this is equivalent to transferring the creditor status to debtor
        // so migrate as internal function of Transfer => debtor?
        Request storage request = requests[requestId];
        require(
            request.status == RequestStatus.Loan
            && (request.creditor == msg.sender || GOVERNOR == msg.sender)
        );

        // first update the debt, so that we can track how much was forgiven
        // if minimum period has not passed yet, do not update it
        if (block.timestamp > request.lastUpdatedAt) {
            request.totalDebt = interestHelper(
                request.totalDebt, request.interestRatePerSecond, block.timestamp - uint256(request.lastUpdatedAt)
            );
            request.lastUpdatedAt = uint40(block.timestamp);
        }
        emit LoanForgiven(requestId, request.totalDebt); // todo log human and creditor too?
        _burn(requestId);
    }

    function interestHelper(uint256 amount, UD60x18 interest, uint256 time) public pure returns (uint256) {
        uint256 compoundedInterest = powu(interest, time).unwrap();
        uint256 compoundedAmount = amount * compoundedInterest / ONE;
        return compoundedAmount;
    }

    // governance stuff

    function changeGovernor(address _governor) external {
        require(msg.sender == GOVERNOR);
        GOVERNOR = _governor;
    }

    function changeTreasury(address _treasury) public {
        require(msg.sender == GOVERNOR);
        TREASURY = _treasury;
    }

    function changeFeeRate(uint16 _feeRate) public {
        require(msg.sender == GOVERNOR);
        FEE_RATE = _feeRate;
    }

    function changeMinimumInterestPeriod(uint256 _period) public {
        require(msg.sender == GOVERNOR);
        MINIMUM_INTEREST_PERIOD = _period;
    }

    function changeMaximumInterestRate(UD60x18 _interest) public {
        require(msg.sender == GOVERNOR);
        MAXIMUM_INTEREST_RATE = _interest;
    }

    // erc721 stuff

    string public constant name = "Raila";
    string public constant symbol = "LOAN";

    function _burn(uint256 _tokenId) internal {
        Request storage request = requests[_tokenId];
        borrowerToRequestId[request.debtor] = 0;
        balanceOf[request.creditor]--;
        emit Transfer(request.creditor, address(0), _tokenId);
        delete requests[_tokenId];
    }

    function _transfer(address sender, address receiver, uint256 tokenId) internal {
        require(receiver != address(0));
        Request storage request = requests[tokenId];
        balanceOf[sender]--;
        balanceOf[receiver]++;
        request.creditor = receiver;
        emit Transfer(sender, receiver, tokenId);
    }

    function approve(address to, uint256 tokenId) external {
        Request storage request = requests[tokenId];
        require(msg.sender == request.creditor);
        getApproved[tokenId] = to;
        emit Approval(msg.sender, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        _transferFromPermission(from, tokenId);
        _transfer(from, to, tokenId);

        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                require(retval == IERC721Receiver.onERC721Received.selector, "Invalid Receiver");
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert ERC721InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        safeTransferFrom(from, to, tokenId, "");
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        _transferFromPermission(from, tokenId);
        _transfer(from, to, tokenId);
    }

    function _transferFromPermission(address from, uint256 tokenId) internal {
        Request storage request = requests[tokenId];
        if (msg.sender != request.creditor) {
            if (isApprovedForAll[from][msg.sender]) {
                // do nothing; already approved for all.
            }
            else {
                require(getApproved[tokenId] == msg.sender);
                // consume the getApproved
                getApproved[tokenId] = address(0);
            }
        }
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return (requests[tokenId].creditor);
    }

    function tokenURI(uint256 tokenId) external pure returns (string memory) {
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(abi.encodePacked('{"name":"Raila Loan","description":"A loan with number ', tokenId, '"}'))
                )
            )
        );
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        // 0x80ac58cd == erc721 ; 0x5b5e139f == erc721metadata
        return interfaceId == 0x80ac58cd || interfaceId == 0x5b5e139f;
    }
}
