// SPDX-License-Identifier: MIT

pragma solidity ^0.8;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IProofOfHumanity} from "../src/IProofOfHumanity.sol";
import {Raila} from "../src/Raila.sol";
import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin-contracts/interfaces/IERC721.sol";
import {UD60x18, powu} from "@prb-math/src/UD60x18.sol";
import "../src/RailaNFTDescriptor.sol";


contract MockPoH is IProofOfHumanity {
    function humanityOf(address owner) public pure returns (bytes20) {
        if (owner == address(1)) return bytes20(address(100)); // alice
        if (owner == address(3)) return bytes20(address(101)); // eve
        else return bytes20(address(0));
    }
    function boundTo(bytes20 _humanityId) public pure returns (address) {
        if (_humanityId == bytes20(address(100))) return address(1); // alice
        if (_humanityId == bytes20(address(101))) return address(3); // eve
        else return address(0);
    }
}

contract PolloCoin is ERC20 {
    constructor(uint256 supply) ERC20("PolloCoin", "CAW") {
        _mint(msg.sender, supply);
    }
}

contract EmptyReceiver {

}

contract RailaTest is Test {
    address alice = address(1);
    address bob = address(2);
    address eve = address(3);
    address charlie = address(10);
    address governor = address(4);
    address treasury = address(5);
    address deployer = address(6);
    bytes20 aliceH = bytes20(address(100));
    bytes20 eveH = bytes20(address(101));

    UD60x18 constant INTEREST_RATE_MAX = UD60x18.wrap(1000000831951620000);
    UD60x18 constant INTEREST_RATE_30_YEAR = UD60x18.wrap(1000000008319516200);
}

contract Constructor is Test {
    IProofOfHumanity poh;
    ERC20 usd;
    Raila raila;
    UD60x18 constant INTEREST_RATE_MAX = UD60x18.wrap(1000000831951620000);

    function setUp() public {
        vm.prank(address(2));
        poh = new MockPoH();
        usd = new PolloCoin(1e18);
    }

    function test_ConstructorSetsVariables() public {
        raila = new Raila(address(4), address(5), 86400 * 90, INTEREST_RATE_MAX, usd, poh, 500);
        assertEq(raila.GOVERNOR(), address(4));
        assertEq(raila.TREASURY(), address(5));
        assertEq(raila.MINIMUM_INTEREST_PERIOD(), 86400 * 90);
        assertEq(address(raila.USD()), address(usd));
        assertEq(address(raila.PROOF_OF_HUMANITY()), address(poh));
        assertEq(raila.FEE_RATE(), 500);
    }
}

contract GovernorChanges is RailaTest {
    IProofOfHumanity poh;
    ERC20 usd;
    Raila raila;

    function setUp() public {
        vm.prank(bob);
        poh = new MockPoH();
        usd = new PolloCoin(1e18);
        raila = new Raila(governor, treasury, 86400 * 90, INTEREST_RATE_MAX, usd, poh, 500);
    }

    function test_ChangeGovernor() public {
        vm.prank(governor);
        raila.changeGovernor(address(1001));
        assertEq(raila.GOVERNOR(), address(1001));
    }

    function test_ChangeGovernorIntruder() public {
        vm.expectRevert(Raila.NotGovernor.selector);
        vm.prank(eve);
        raila.changeGovernor(address(1001));
    }

    function test_ChangeTreasury() public {
        vm.prank(governor);
        raila.changeTreasury(address(1001));
        assertEq(raila.TREASURY(), address(1001));
    }

    function test_ChangeTreasuryIntruder() public {
        vm.expectRevert(Raila.NotGovernor.selector);
        vm.prank(eve);
        raila.changeTreasury(address(1001));
    }

    function test_ChangeFeeRate() public {
        vm.prank(governor);
        raila.changeFeeRate(100);
        assertEq(raila.FEE_RATE(), 100);
    }

    function test_ChangeFeeRateIntruder() public {
        vm.expectRevert(Raila.NotGovernor.selector);
        vm.prank(eve);
        raila.changeFeeRate(100);
    }

    function test_ChangeMinInterestPeriod() public {
        vm.prank(governor);
        raila.changeMinimumInterestPeriod(60 days);
        assertEq(raila.MINIMUM_INTEREST_PERIOD(), 60 days);
    }

    function test_ChangeMinInterestPeriodIntruder() public {
        vm.expectRevert(Raila.NotGovernor.selector);
        vm.prank(eve);
        raila.changeMinimumInterestPeriod(60 days);
    }

    function test_ChangeMaxInterestRate() public {
        vm.prank(governor);
        raila.changeMaximumInterestRate(INTEREST_RATE_30_YEAR);
        assertEq(
            UD60x18.unwrap(raila.MAXIMUM_INTEREST_RATE()),
            UD60x18.unwrap(INTEREST_RATE_30_YEAR)
        );
    }

    function test_ChangeMaxInterestRateIntruder() public {
        vm.expectRevert(Raila.NotGovernor.selector);
        vm.prank(eve);
        raila.changeMaximumInterestRate(INTEREST_RATE_30_YEAR);
    }

    function test_ChangeNFTDescriptor() public {
        vm.prank(governor);
        raila.changeNftDescriptor(RailaNFTDescriptor(address(0x00)));
    }

    function test_ChangeNFTDescriptorIntruder() public {
        vm.expectRevert(Raila.NotGovernor.selector);
        vm.prank(eve);
        raila.changeNftDescriptor(RailaNFTDescriptor(address(0x00)));
    }
}

contract CreateRequest is RailaTest {
    IProofOfHumanity poh;
    ERC20 usd;
    Raila raila;

    function setUp() public {
        poh = new MockPoH();
        vm.prank(bob);
        usd = new PolloCoin(1e18);
        raila = new Raila(governor, treasury, 86400 * 90, INTEREST_RATE_MAX, usd, poh, 500);
    }

    function test_RequestLogs() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Raila.RequestCreation(aliceH, 1, "");
        raila.createRequest(1 ether, INTEREST_RATE_30_YEAR, 2 ether, "");
    }

    function test_RequestReads() public {
        vm.prank(alice);
        uint256 requestId = raila.createRequest(1 ether, INTEREST_RATE_30_YEAR, 2 ether, "");
        assertEq(requestId, 1);
        // must mutate requestCounter, add reference borrower => request, and request data
        assertEq(raila.lastRequestId(), 1);
        assertEq(raila.borrowerToRequestId(aliceH), 1);

        (bytes20 debtor, uint40 createdAtBlock, Raila.RequestStatus status, address creditor, uint40 fundedAt,
        uint40 lastUpdatedAt, uint16 feeRate, UD60x18 interestRatePerSecond,
        uint256 originalDebt, uint256 totalDebt, uint256 defaultThreshold) = raila.requests(1);
        vm.assertEq(debtor, aliceH);
        vm.assertEq(createdAtBlock, block.number);
        vm.assertEq(uint8(status), uint8(Raila.RequestStatus.Open));
        vm.assertEq(creditor, address(0));
        vm.assertEq(fundedAt, 0); // wasn't funded yet
        vm.assertEq(lastUpdatedAt, 0); 
        vm.assertEq(feeRate, 0); // fee rate is not set here, but on acceptRequest
        vm.assertEq(interestRatePerSecond.unwrap(), INTEREST_RATE_30_YEAR.unwrap());
        vm.assertEq(originalDebt, 1 ether);
        vm.assertEq(totalDebt, 0);
        vm.assertEq(defaultThreshold, 2 ether);
    }

    function test_RequestZeroDoesNotExistAlwaysContainsEmptyData() public {
        vm.prank(alice);
        // create a request for good measure, ensure it won't overwrite it
        raila.createRequest(1 ether, INTEREST_RATE_30_YEAR, 2 ether, "");
        (bytes20 debtor, uint40 createdAtBlock, Raila.RequestStatus status, address creditor, uint40 fundedAt,
        uint40 lastUpdatedAt, uint16 feeRate, UD60x18 interestRatePerSecond,
        uint256 originalDebt, uint256 totalDebt, uint256 defaultThreshold) = raila.requests(0);
        vm.assertEq(debtor, bytes20(address(0)));
        vm.assertEq(createdAtBlock, 0);
        vm.assertEq(uint8(status), uint8(Raila.RequestStatus.Open));
        vm.assertEq(creditor, address(0));
        vm.assertEq(fundedAt, 0); // wasn't funded yet
        vm.assertEq(lastUpdatedAt, 0); 
        vm.assertEq(feeRate, 0);
        vm.assertEq(interestRatePerSecond.unwrap(), 0);
        vm.assertEq(originalDebt, 0);
        vm.assertEq(totalDebt, 0);
        vm.assertEq(defaultThreshold, 0);
    }

    function test_RequesterMustBeHuman() public {
        vm.expectRevert(Raila.NotHuman.selector);
        vm.prank(bob);
        raila.createRequest(1 ether, INTEREST_RATE_30_YEAR, 2 ether, "");
    }

    function test_MaxOneRequestPerHuman() public {
        vm.prank(alice);
        raila.createRequest(1 ether, INTEREST_RATE_30_YEAR, 2 ether, "");
        vm.expectRevert(Raila.RequestAlreadyExists.selector);
        vm.prank(alice);
        raila.createRequest(1 ether, INTEREST_RATE_30_YEAR, 2 ether, "");
    }

    function test_StartingOwedAmountMustBeUnderDefaultsAt() public {
        vm.expectRevert(Raila.RequestWouldDefault.selector);
        vm.prank(alice);
        raila.createRequest(1 ether, INTEREST_RATE_30_YEAR, 1 ether, "");
    }

    function test_StartingOwedAmountMustBeUnderDefaultsAtInterestIncluded() public {
        vm.expectRevert(Raila.RequestWouldDefault.selector);
        vm.prank(alice);
        raila.createRequest(1 ether, INTEREST_RATE_30_YEAR, 1.01 ether, "");
    }

    // just checking close cases that might break 
    function test_StartingOwedAmountBarelyDefaultsAtInterestIncluded() public {
        vm.expectRevert(Raila.RequestWouldDefault.selector);
        vm.prank(alice);
        raila.createRequest(1 ether, INTEREST_RATE_30_YEAR, 1.06683 ether, "");
    }

    // just checking a close case that might break 
    function test_StartingOwedAmountBarelyNotDefaultsAtInterestIncluded() public {
        vm.prank(alice);
        raila.createRequest(1 ether, INTEREST_RATE_30_YEAR, 1.06684 ether, "");
    }

    // intended: NOOPs, interfaces/subgraph will hide useless logs
    function test_RequesterCanRequestZero() public {
        vm.prank(alice);
        raila.createRequest(0, INTEREST_RATE_30_YEAR, 1 ether, "");
    }

    // although if the defaultsAt is also zero it won't allow it
    function test_RequestOfZeroFailsWithZeroDefaultsAt() public {
        vm.expectRevert(Raila.RequestWouldDefault.selector);
        vm.prank(alice);
        raila.createRequest(0, INTEREST_RATE_30_YEAR, 0, "");
    }

    // the user cannot condemn themselves to infinite debt
    function test_RequesterInsaneInterest() public {
        vm.expectRevert(Raila.RequestBadInterestRate.selector);
        vm.prank(alice);
        UD60x18 INTEREST_RATE_OVER_500000_YEAR = UD60x18.wrap(1000002000000000000);
        raila.createRequest(1 ether, INTEREST_RATE_OVER_500000_YEAR, 20000 ether, "");
    }

    // the user cannot request a negative interest debt
    function test_RequesterNegativeInterest() public {
        vm.expectRevert(Raila.RequestBadInterestRate.selector);
        vm.prank(alice);
        UD60x18 INTEREST_RATE_NEGATIVE = UD60x18.wrap(900000000000000000);
        raila.createRequest(1 ether, INTEREST_RATE_NEGATIVE, 2 ether, "");
    }

    // the user cannot request a 0% interest debt
    function test_RequesterZeroInterest() public {
        vm.expectRevert(Raila.RequestBadInterestRate.selector);
        vm.prank(alice);
        UD60x18 INTEREST_RATE_ZERO = UD60x18.wrap(1000000000000000000);
        raila.createRequest(1 ether, INTEREST_RATE_ZERO, 2 ether, "");
    }
}

contract CancelRequest is RailaTest {
    IProofOfHumanity poh;
    ERC20 usd;
    Raila raila;

    function setUp() public {
        poh = new MockPoH();
        vm.prank(bob);
        usd = new PolloCoin(100 ether);
        raila = new Raila(governor, treasury, 86400 * 90, INTEREST_RATE_MAX, usd, poh, 500);
        vm.prank(alice);
        raila.createRequest(1 ether, INTEREST_RATE_30_YEAR, 2 ether, "");
        // request will be at 1
    }

    function test_AliceCancelsHerRequest() public {
        vm.prank(alice);
        raila.cancelRequest();
    }

    function test_CancelRequestLogs() public {
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit Raila.RequestCanceled(1);
        raila.cancelRequest();
    }

    function test_CancelRequestReads() public {
        vm.prank(alice);
        raila.cancelRequest();

        assertEq(raila.lastRequestId(), 1); // had incremented
        assertEq(raila.borrowerToRequestId(aliceH), 0); // ref must be erased

        // cancelling a request must delete all struct data
        (bytes20 debtor, uint40 createdAtBlock, Raila.RequestStatus status, address creditor, uint40 fundedAt,
        uint40 lastUpdatedAt, uint16 feeRate, UD60x18 interestRatePerSecond,
        uint256 originalDebt, uint256 totalDebt, uint256 defaultThreshold) = raila.requests(1);
        vm.assertEq(debtor, bytes20(address(0)));
        vm.assertEq(createdAtBlock, 0);
        vm.assertEq(uint8(status), uint8(0));
        vm.assertEq(creditor, address(0));
        vm.assertEq(fundedAt, 0);
        vm.assertEq(lastUpdatedAt, 0); 
        vm.assertEq(feeRate, 0);
        vm.assertEq(interestRatePerSecond.unwrap(), 0);
        vm.assertEq(originalDebt, 0);
        vm.assertEq(totalDebt, 0);
        vm.assertEq(defaultThreshold, 0);
    }

    function test_NonHumanCannotCancelRequest() public {
        vm.expectRevert(Raila.NotRequest.selector);
        vm.prank(bob);
        raila.cancelRequest();
    }

    function test_EveCannotCancelRequest() public {
        // because she doesn't have an open request
        vm.expectRevert(Raila.NotRequest.selector);
        vm.prank(eve);
        raila.cancelRequest();
    }

    function test_CannotCancelRequestIfLoanBegan() public {
        vm.prank(bob);
        usd.approve(address(raila), 1 ether);
        vm.prank(bob);
        raila.acceptRequest(1);

        vm.expectRevert(Raila.LoanActive.selector);
        vm.prank(alice);
        raila.cancelRequest();
    }
}

contract AcceptRequest is RailaTest {
    IProofOfHumanity poh;
    ERC20 usd;
    Raila raila;

    function setUp() public {
        poh = new MockPoH();
        vm.prank(bob);
        usd = new PolloCoin(100 ether);
        raila = new Raila(governor, treasury, 86400 * 90, INTEREST_RATE_MAX, usd, poh, 500);
        vm.prank(alice);
        raila.createRequest(1 ether, INTEREST_RATE_30_YEAR, 2 ether, "");
        // request will be at 1
    }

    function test_CreditorCanAcceptRequest() public {
        vm.prank(bob);
        usd.approve(address(raila), 1 ether);
        vm.prank(bob);
        raila.acceptRequest(1);
    }

    function test_AcceptRequestLogs() public {
        vm.prank(bob);
        usd.approve(address(raila), 1 ether);
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(bob, alice, 1 ether);
        vm.expectEmit(true, true, true, false, address(raila));
        emit IERC721.Transfer(address(0), bob, 1); // loan nft mint
        vm.prank(bob);
        raila.acceptRequest(1);
    }

    function test_AcceptRequestReads() public {
        vm.prank(bob);
        usd.approve(address(raila), 1 ether);
        vm.prank(bob);
        raila.acceptRequest(1);

        (bytes20 debtor, uint40 createdAtBlock, Raila.RequestStatus status, address creditor, uint40 fundedAt,
        uint40 lastUpdatedAt, uint16 feeRate, UD60x18 interestRatePerSecond,
        uint256 originalDebt, uint256 totalDebt, uint256 defaultThreshold) = raila.requests(1);
        vm.assertEq(debtor, aliceH);
        vm.assertEq(createdAtBlock, block.number);
        vm.assertEq(uint8(status), uint8(1));
        vm.assertEq(creditor, bob);
        vm.assertEq(fundedAt, block.timestamp);
        vm.assertEq(lastUpdatedAt, block.timestamp + 86400 * 90); 
        vm.assertEq(feeRate, 500);
        vm.assertEq(interestRatePerSecond.unwrap(), INTEREST_RATE_30_YEAR.unwrap());
        vm.assertEq(originalDebt, 1 ether);
        vm.assertEq(totalDebt, 1066830984986877400); // precompounded for minimum period
        vm.assertEq(defaultThreshold, 2 ether);

        vm.assertEq(raila.borrowerToRequestId(aliceH), 1); // alice still borrower
        vm.assertEq(raila.balanceOf(bob), 1); // owner of the nft = creditor of loan

        // check new balances
        vm.assertEq(usd.balanceOf(bob), 99 ether); // creditor started 100 but lost 1
        vm.assertEq(usd.allowance(bob, address(raila)), 0 ether); // spent allowance
        vm.assertEq(usd.balanceOf(alice), 1 ether); // alice got 1
    }
    
    // getting out of stack;
    // https://etherscan.io/address/0x91ae842a5ffd8d12023116943e72a606179294f3#code
    function test_NFTDescriptorForLoan() public {
        vm.prank(bob);
        usd.approve(address(raila), 1 ether);
        vm.prank(bob);
        raila.acceptRequest(1);
        // how to read this:
        // goto https://www.base64decode.org/ ; should reveal NFT metadata {name, description, image}
        // under image, there's another base64 image. paste it to reveal the svg
        vm.assertEq(raila.tokenURI(1), "data:application/json;base64,eyJuYW1lIjogIlJhaWxhIExvYW4iLCAiZGVzY3JpcHRpb24iOiJUaGlzIE5GVCByZXByZXNlbnRzIGFuIHVuY29sbGF0ZXJhbGl6ZWQgbG9hbiBpbiBSYWlsYS4gVGhlIG93bmVyIG9mIHRoaXMgTkZUIGlzIHRoZSBjcmVkaXRvciwgYW5kIGlzIGVudGl0bGVkIHRvIHJlY2VpdmUgdGhlIGZ1bmRzIHBlbmRpbmcgcGF5bWVudCBwbHVzIGFkZGl0aW9uYWwgaW50ZXJlc3QsIGlzIGFibGUgdG8gdHJhbnNmZXIgdGhlIGNyZWRpdG9yIHN0YXR1cywgYW5kIGFibGUgdG8gZm9yZ2l2ZSB0aGUgZGVidC5cbiBUaGUgZGVidG9yIG9mIHRoaXMgbG9hbiBpcyB0aGUgaHVtYW4gd2l0aCBodW1hbml0eUlkOiAweDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwNjQuXG4gRmFpbGluZyB0byBwYXkgdGhlIGRlYnQgaW4gdGltZSwgc3VjaCB0aGF0IHRoZSBkZWJ0IGV4Y2VlZHMgdGhlIGRlZmF1bHQgdGhyZXNob2xkLCB3aWxsIGluY2x1ZGUgdGhlIGRlYnRvciwgYXMgYSBodW1hbiwgaW4gYSBsaXN0IG9mIGtub3duIGRlZmF1bHRlcnMuIFJhaWxhIHByb3RvY29sIGZlZSBhdCA1JSBvZiByZWFsaXplZCBpbnRlcmVzdC4iLCAiaW1hZ2UiOiAiZGF0YTppbWFnZS9zdmcreG1sO2Jhc2U2NCxQSE4yWnlCM2FXUjBhRDBpT0RVM0lpQm9aV2xuYUhROUlqVXdNQ0lnZG1sbGQwSnZlRDBpTUNBd0lEZzFOeUExTURBaUlHWnBiR3c5SW01dmJtVWlJSGh0Ykc1elBTSm9kSFJ3T2k4dmQzZDNMbmN6TG05eVp5OHlNREF3TDNOMlp5SWdlRzFzYm5NNmVHeHBibXM5SW1oMGRIQTZMeTkzZDNjdWR6TXViM0puTHpFNU9Ua3ZlR3hwYm1zaVBqeGtaV1p6UGlBZ0lDQThjM2x0WW05c0lHbGtQU0pzYjJkdklpQjJhV1YzUW05NFBTSXdJREFnTkRBd0lEWTFNQ0krSUR4blBpQThjR0YwYUNCa1BTSk5NamM1TGpVZ01UVTRMalZETWpFNUxqa2dNVEUyTGpFZ01qRTJJRFEwTGpnek16TWdNakl4TGpVZ01UUXVOVU14TnpBdU56SWdPRE11TURrNE5pQXhOalV1TWpZNUlERTFNeTR5TnpjZ01qRTJJREl5TVVNeU5qY3VNekUzSURJNE9TNDFNRFFnTXpBeExqUXhNeUF5T1RrdU5EVTNJRE15TlM0MUlETTRPRU16TkRNdU9UUTBJRFExTlM0NElETXdNeTQxTmprZ05UQTVMamt6TVNBeU9EY3VOU0ExTXpaRE16QXpMalEyTVNBMU1qVXVOekF5SURNek9DNDVORGNnTlRFd0xqUTBOeUF6TnpjdU5TQTBOakl1TlVNME5qa3VNRFV4SURNME9DNDJORE1nTXpjMkxqUXdNU0F5TWpjdU5ETTNJREkzT1M0MUlERTFPQzQxV2lJZ0x6NGdQSEJoZEdnZ1pEMGlUVEkxTXk0MUlEVTBOaTQxUXpJNU5DQTFNRElnTXpBNUxqSXlOeUEwTmpJdU5EY3hJRE13Tnk0MUlEUXhNVU16TURVdU16QTNJRE0wTlM0Mk5EY2dNalEwTGprNE5TQXlPRGt1T0RBeklESXdOU0F5TkRNdU5VTXhNell1TVRjeElERTJPQzQyT1RrZ01UUTFMak13T1NBM01DNHhORFkzSURJd05TQXlRemcwTGpFNU1UWWdOREl1TURZMElDMDFNaTQ0TWpFZ01UY3pMakF4TlNBMU15QXpNREJET0RjZ016UXdMamdnTVRJekxqTXpNeUF6T0RFdU1UWTNJREV6T0NBek9UVkRNVFE1SURRd05TNHpNek1nTVRjMExqZ2dORE0zTGpZZ01Ua3dJRFE0TkVNeU1EVXVNaUExTXpBdU5DQXhOemt1TXpNeklEVTVOeUF4TmpRdU5TQTJNalF1TlVNeE9EQXVOalkzSURZeE15NHpNek1nTWpJeExqRWdOVGd5TGpFZ01qVXpMalVnTlRRMkxqVmFJaUF2UGlBOGNHRjBhQ0JrUFNKTk5UVXVOU0F6TkRCRE5ETXVOU0F6TWpZdU5DQXlOeTR4TmpZM0lETXdNUzR6TXpNZ01qQXVOU0F5T1RBdU5VTXROaTQxTVRBME1pQXpORFV1TVRZMElDMHhNQzQyT1RjeUlEUTBOaTQwTnpnZ05EWWdORGcyTGpWRE9UUXVOamd4TkNBMU1qQXVPRFl6SURFek1DNDVNeklnTlRVMkxqUXhNeUF4TkRVZ05qRTFMalZETVRVd0lEWXdOU0F4TmpFdU5pQTFOemd1T1NBeE5qZ2dOVFU0TGpWRE1UazNMalEzSURRMk5DNDFOalVnTVRFd0xqSTFNU0EwTURJdU1EVXhJRFUxTGpVZ016UXdXaUlnTHo0Z1BDOW5QaUE4TDNONWJXSnZiRDRnSUNBZ1BITjViV0p2YkNCcFpEMGljbUZwYkdFdGJHOW5ieUlnZG1sbGQwSnZlRDBpTUNBd0lERTROUzQzTmpRZ05qY3VNakl6SWo0Z1BHYytJRHh3WVhSb0lHUTlJazBnTnk0NU1UY2dOall1TmpZM0lFd2dNQ0EyTmk0Mk5qY2dUQ0F3SURRdU1UWTNJRXdnTVRVdU5qazBJRFF1TVRZM0lFRWdNalF1TnpNMUlESTBMamN6TlNBd0lEQWdNU0F5TUM0MU5DQTBMall4T1NCQklERTRMakExTnlBeE9DNHdOVGNnTUNBd0lERWdNalV1T0RNeklEWXVOVEk0SUVFZ01UZ3VNVEEzSURFNExqRXdOeUF3SURBZ01TQXpNQzQxTWpRZ01UQXVNakU0SUVFZ01UWXVOVE16SURFMkxqVXpNeUF3SURBZ01TQXpNaTR6T1RZZ01USXVOelF6SUVFZ01UWXVNREkwSURFMkxqQXlOQ0F3SURBZ01TQXpOQzQzTWpJZ01qRXVNVGd4SUZFZ016UXVOekl5SURJMkxqTXhPU0F6TVM0NE1EWWdNekF1TkRFM0lFRWdNVFl1TnpVMUlERTJMamMxTlNBd0lEQWdNU0F5TkM0M055QXpOaTR3TmpZZ1FTQXlNQzQxTXpZZ01qQXVOVE0ySURBZ01DQXhJREl6TGpneE9TQXpOaTQwTlRnZ1RDQTBOQzQzT1RJZ05qWXVOalkzSUV3Z016VXVOVFUySURZMkxqWTJOeUJNSURFMUxqWTVOQ0F6Tnk0NU1UY2dUQ0EzTGpreE55QXpOeTQ1TVRjZ1RDQTNMamt4TnlBMk5pNDJOamNnV2lCTklEZzBMak0zTlNBek1DNDBPRFlnVENBNE5DNHpOelVnTWpVZ1RDQTVNUzR6TVRrZ01qVWdUQ0E1TVM0ek1Ua2dOall1TmpZM0lFd2dPRFF1TXpjMUlEWTJMalkyTnlCTUlEZzBMak0zTlNBMk1TNHhPREVnVVNBNE1TNDFPVGNnTmpNdU9UVTRJRGMzTGpneE15QTJOUzQxT1NCQklESXdMakl4TWlBeU1DNHlNVElnTUNBd0lERWdOamt1TnpJeUlEWTNMakl5TWlCQklERTVMall4TVNBeE9TNDJNVEVnTUNBd0lERWdOVGt1TXpBMklEWTBMak0wSUZFZ05UUXVOVGd6SURZeExqUTFPQ0ExTVM0M056RWdOVFl1TlRrM0lGRWdORGd1T1RVNElEVXhMamN6TmlBME9DNDVOVGdnTkRVdU9ETXpJRkVnTkRndU9UVTRJRE01TGprek1TQTFNUzQzTnpFZ016VXVNRFk1SUZFZ05UUXVOVGd6SURNd0xqSXdPQ0ExT1M0ek1EWWdNamN1TXpJMklFRWdNVGt1TmpFeElERTVMall4TVNBd0lEQWdNU0EyT1M0M01qSWdNalF1TkRRMElFRWdNakF1TlRreUlESXdMalU1TWlBd0lEQWdNU0EzTnk0NE1UTWdNall1TURReUlGRWdPREV1TlRrM0lESTNMall6T1NBNE5DNHpOelVnTXpBdU5EZzJJRm9nVFNBeE56Z3VPREU1SURNd0xqUTROaUJNSURFM09DNDRNVGtnTWpVZ1RDQXhPRFV1TnpZMElESTFJRXdnTVRnMUxqYzJOQ0EyTmk0Mk5qY2dUQ0F4TnpndU9ERTVJRFkyTGpZMk55Qk1JREUzT0M0NE1Ua2dOakV1TVRneElGRWdNVGMyTGpBME1pQTJNeTQ1TlRnZ01UY3lMakkxTnlBMk5TNDFPU0JCSURJd0xqSXhNaUF5TUM0eU1USWdNQ0F3SURFZ01UWTBMakUyTnlBMk55NHlNaklnUVNBeE9TNDJNVEVnTVRrdU5qRXhJREFnTUNBeElERTFNeTQzTlNBMk5DNHpOQ0JSSURFME9TNHdNamdnTmpFdU5EVTRJREUwTmk0eU1UVWdOVFl1TlRrM0lGRWdNVFF6TGpRd015QTFNUzQzTXpZZ01UUXpMalF3TXlBME5TNDRNek1nVVNBeE5ETXVOREF6SURNNUxqa3pNU0F4TkRZdU1qRTFJRE0xTGpBMk9TQlJJREUwT1M0d01qZ2dNekF1TWpBNElERTFNeTQzTlNBeU55NHpNallnUVNBeE9TNDJNVEVnTVRrdU5qRXhJREFnTUNBeElERTJOQzR4TmpjZ01qUXVORFEwSUVFZ01qQXVOVGt5SURJd0xqVTVNaUF3SURBZ01TQXhOekl1TWpVM0lESTJMakEwTWlCUklERTNOaTR3TkRJZ01qY3VOak01SURFM09DNDRNVGtnTXpBdU5EZzJJRm9nVFNBeE16SXVPVGcySURZMkxqWTJOeUJNSURFeU5TNDBPRFlnTmpZdU5qWTNJRXdnTVRJMUxqUTROaUF3SUV3Z01UTXlMams0TmlBd0lFd2dNVE15TGprNE5pQTJOaTQyTmpjZ1dpQk5JREV4TWk0eE5UTWdOall1TmpZM0lFd2dNVEEwTGpZMU15QTJOaTQyTmpjZ1RDQXhNRFF1TmpVeklESTFJRXdnTVRFeUxqRTFNeUF5TlNCTUlERXhNaTR4TlRNZ05qWXVOalkzSUZvZ1RTQTNNQzQyT1RRZ05qQXVOREUzSUVFZ01UTXVORGd6SURFekxqUTRNeUF3SURBZ01DQTNOeTQ0T0RJZ05UZ3VORE00SUVFZ01UUXVOemMxSURFMExqYzNOU0F3SURBZ01DQTRNeTR3TWpFZ05UTXVNVFlnVVNBNE5DNDVNekVnTkRrdU9EWXhJRGcwTGprek1TQTBOUzQ0TXpNZ1FTQXhOQzQyTkRFZ01UUXVOalF4SURBZ01DQXdJRGd6TGpnek5DQTBNQzR4TkRjZ1FTQXhOQzR3TlRnZ01UUXVNRFU0SURBZ01DQXdJRGd6TGpBeU1TQXpPQzQxTURjZ1VTQTRNUzR4TVRFZ016VXVNakE0SURjM0xqZzRNaUF6TXk0eU1qa2dRU0F4TXk0ME9ETWdNVE11TkRneklEQWdNQ0F3SURjd0xqWTVOQ0F6TVM0eU5TQkJJREV6TGpRNE15QXhNeTQwT0RNZ01DQXdJREFnTmpNdU5UQTNJRE16TGpJeU9TQkJJREUwTGpjM05TQXhOQzQzTnpVZ01DQXdJREFnTlRndU16WTRJRE00TGpVd055QlJJRFUyTGpRMU9DQTBNUzQ0TURZZ05UWXVORFU0SURRMUxqZ3pNeUJCSURFMExqWTBNU0F4TkM0Mk5ERWdNQ0F3SURBZ05UY3VOVFUxSURVeExqVXhPU0JCSURFMExqQTFPQ0F4TkM0d05UZ2dNQ0F3SURBZ05UZ3VNelk0SURVekxqRTJJRkVnTmpBdU1qYzRJRFUyTGpRMU9DQTJNeTQxTURjZ05UZ3VORE00SUVFZ01UTXVORGd6SURFekxqUTRNeUF3SURBZ01DQTNNQzQyT1RRZ05qQXVOREUzSUZvZ1RTQXhOalV1TVRNNUlEWXdMalF4TnlCQklERXpMalE0TXlBeE15NDBPRE1nTUNBd0lEQWdNVGN5TGpNeU5pQTFPQzQwTXpnZ1FTQXhOQzQzTnpVZ01UUXVOemMxSURBZ01DQXdJREUzTnk0ME5qVWdOVE11TVRZZ1VTQXhOemt1TXpjMUlEUTVMamcyTVNBeE56a3VNemMxSURRMUxqZ3pNeUJCSURFMExqWTBNU0F4TkM0Mk5ERWdNQ0F3SURBZ01UYzRMakkzT0NBME1DNHhORGNnUVNBeE5DNHdOVGdnTVRRdU1EVTRJREFnTUNBd0lERTNOeTQwTmpVZ016Z3VOVEEzSUZFZ01UYzFMalUxTmlBek5TNHlNRGdnTVRjeUxqTXlOaUF6TXk0eU1qa2dRU0F4TXk0ME9ETWdNVE11TkRneklEQWdNQ0F3SURFMk5TNHhNemtnTXpFdU1qVWdRU0F4TXk0ME9ETWdNVE11TkRneklEQWdNQ0F3SURFMU55NDVOVEVnTXpNdU1qSTVJRUVnTVRRdU56YzFJREUwTGpjM05TQXdJREFnTUNBeE5USXVPREV5SURNNExqVXdOeUJSSURFMU1DNDVNRE1nTkRFdU9EQTJJREUxTUM0NU1ETWdORFV1T0RNeklFRWdNVFF1TmpReElERTBMalkwTVNBd0lEQWdNQ0F4TlRFdU9UazVJRFV4TGpVeE9TQkJJREUwTGpBMU9DQXhOQzR3TlRnZ01DQXdJREFnTVRVeUxqZ3hNaUExTXk0eE5pQlJJREUxTkM0M01qSWdOVFl1TkRVNElERTFOeTQ1TlRFZ05UZ3VORE00SUVFZ01UTXVORGd6SURFekxqUTRNeUF3SURBZ01DQXhOalV1TVRNNUlEWXdMalF4TnlCYUlFMGdOeTQ1TVRjZ01URXVNalVnVENBM0xqa3hOeUF6TVM0eU5TQk1JREUxTGpZNU5DQXpNUzR5TlNCQklERTNMamd4TXlBeE55NDRNVE1nTUNBd0lEQWdNVGd1TXprM0lETXhMakExTnlCUklESXdMall6TXlBek1DNDNNVE1nTWpJdU1qVTNJREk1TGpjMU55QlJJREkwTGpjNU1pQXlPQzR5TmpRZ01qWXVNREEzSURJMUxqa3pPQ0JCSURFd0xqWXhNU0F4TUM0Mk1URWdNQ0F3SURBZ01qY3VNRGM1SURJeUxqZ3pPU0JCSURrdU5qTTBJRGt1TmpNMElEQWdNQ0F3SURJM0xqSXlNaUF5TVM0eE9ERWdRU0E1TGpnMU5TQTVMamcxTlNBd0lEQWdNQ0F5Tmk0MU5URWdNVGN1TkRnM0lFRWdPUzR3TlRZZ09TNHdOVFlnTUNBd0lEQWdNalF1TURZeUlERTBMakF5T0NCQklERXdMamd4TmlBeE1DNDRNVFlnTUNBd0lEQWdNVGt1TWpReklERXhMall5TlNCQklERTFMamc1TXlBeE5TNDRPVE1nTUNBd0lEQWdNVFV1TmprMElERXhMakkxSUV3Z055NDVNVGNnTVRFdU1qVWdXaUJOSURFd05DNDVNRGNnTVRZdU1EZzNJRUVnTkM0NE1UY2dOQzQ0TVRjZ01DQXdJREFnTVRBNExqUXdNeUF4Tnk0MUlFRWdOaTR5TlRZZ05pNHlOVFlnTUNBd0lEQWdNVEE0TGpVek55QXhOeTQwT1RrZ1FTQTBMamMyTlNBMExqYzJOU0F3SURBZ01DQXhNVEV1T1RjNUlERTJMakEwTWlCQklEVXVNREE1SURVdU1EQTVJREFnTUNBd0lERXhNaTQ1TWpjZ01UUXVOeUJCSURVdU1ETTJJRFV1TURNMklEQWdNQ0F3SURFeE15NDBNRE1nTVRJdU5TQlJJREV4TXk0ME1ETWdNVEF1TXpRM0lERXhNUzQ1TnprZ09DNDVNalFnUVNBMExqY3hOaUEwTGpjeE5pQXdJREFnTUNBeE1UQXVNalUwSURjdU9ERWdRU0ExTGpNek9TQTFMak16T1NBd0lEQWdNQ0F4TURndU5EQXpJRGN1TlNCQklEUXVPRGd5SURRdU9EZ3lJREFnTUNBd0lERXdOQzQ0TmpFZ09DNDVNalFnVVNBeE1ETXVOREF6SURFd0xqTTBOeUF4TURNdU5EQXpJREV5TGpVZ1FTQTFMamt4TWlBMUxqa3hNaUF3SURBZ01DQXhNRE11TkRBeklERXlMalUyTlNCQklEUXVPREUxSURRdU9ERTFJREFnTUNBd0lERXdOQzQ0TmpFZ01UWXVNRFF5SUVFZ05TNDNNemtnTlM0M016a2dNQ0F3SURBZ01UQTBMamt3TnlBeE5pNHdPRGNnV2lJZ2RtVmpkRzl5TFdWbVptVmpkRDBpYm05dUxYTmpZV3hwYm1jdGMzUnliMnRsSWlBdlBpQThMMmMrSUR3dmMzbHRZbTlzUGlBZ0lDQThiR2x1WldGeVIzSmhaR2xsYm5RZ2FXUTlJbWR5WVdRaUlHZHlZV1JwWlc1MFZISmhibk5tYjNKdFBTSnliM1JoZEdVb01qQXBJajRnUEhOMGIzQWdiMlptYzJWMFBTSTFNQ1VpSUhOMGIzQXRZMjlzYjNJOUlpTmlPVFUyTXpJaUlDOCtJRHh6ZEc5d0lHOW1abk5sZEQwaU1UQXdKU0lnYzNSdmNDMWpiMnh2Y2owaUl6aG1ORFl5TlNJZ0x6NGdQQzlzYVc1bFlYSkhjbUZrYVdWdWRENGdJQ0FnUEd4cGJtVmhja2R5WVdScFpXNTBJR2xrUFNKamRYSjJaUzFuY21Ga0lpQm5jbUZrYVdWdWRGUnlZVzV6Wm05eWJUMGljbTkwWVhSbEtEQXBJajRnUEhOMGIzQWdiMlptYzJWMFBTSXdKU0lnYzNSdmNDMWpiMnh2Y2owaUl6UTRabVl3TUNJZ0x6NGdQSE4wYjNBZ2IyWm1jMlYwUFNJeE1EQWxJaUJ6ZEc5d0xXTnZiRzl5UFNJalpUY3dNREF3SWlBdlBpQThMMnhwYm1WaGNrZHlZV1JwWlc1MFBpQWdJQ0E4YzNsdFltOXNJR2xrUFNKamRYSjJaU0lnZG1sbGQwSnZlRDBpTUNBd0lESTFNaUF5TVRRaVBpQThjR0YwYUNCa1BTSk5OQ0F5TURWRE1URTJJREl3TlNBeU5EY2dNVEExSURJME55QXdJaUF2UGlBOEwzTjViV0p2YkQ0Z0lDQWdQR05zYVhCUVlYUm9JR2xrUFNKeVpXTjBMV05zYVhBaVBpQThjbVZqZENCNFBTSTFJaUI1UFNJMUlpQjNhV1IwYUQwaU9EUTNJaUJvWldsbmFIUTlJalE1TUNJZ2NuZzlJalF3SWlCeWVUMGlNekFpSUM4K0lEd3ZZMnhwY0ZCaGRHZytJQ0FnSUR4bWFXeDBaWElnYVdROUltUnliM0J6YUdGa2IzY2lJR2hsYVdkb2REMGlNVE13SlNJK0lEeG1aVWRoZFhOemFXRnVRbXgxY2lCcGJqMGlVMjkxY21ObFFXeHdhR0VpSUhOMFpFUmxkbWxoZEdsdmJqMGlNeUlnTHo0Z1BHWmxUMlptYzJWMElHUjRQU0l4TUNJZ1pIazlJakV3SWlCeVpYTjFiSFE5SW05bVpuTmxkR0pzZFhJaUlDOCtJRHhtWlVOdmJYQnZibVZ1ZEZSeVlXNXpabVZ5UGlBOFptVkdkVzVqUVNCMGVYQmxQU0pzYVc1bFlYSWlJSE5zYjNCbFBTSXhJaUF2UGlBOEwyWmxRMjl0Y0c5dVpXNTBWSEpoYm5ObVpYSStJRHhtWlUxbGNtZGxQaUE4Wm1WTlpYSm5aVTV2WkdVZ0x6NGdQR1psVFdWeVoyVk9iMlJsSUdsdVBTSlRiM1Z5WTJWSGNtRndhR2xqSWlBdlBqd3ZabVZOWlhKblpUNGdQQzltYVd4MFpYSStJQ0FnSUR4bWFXeDBaWElnYVdROUltUnliM0J6YUdGa2IzY3lJaUJvWldsbmFIUTlJakV6TUNVaVBpQThabVZIWVhWemMybGhia0pzZFhJZ2FXNDlJbE52ZFhKalpVRnNjR2hoSWlCemRHUkVaWFpwWVhScGIyNDlJakVpSUM4K0lEeG1aVTltWm5ObGRDQmtlRDBpTXlJZ1pIazlJak1pSUhKbGMzVnNkRDBpYjJabWMyVjBZbXgxY2lJZ0x6NGdQR1psUTI5dGNHOXVaVzUwVkhKaGJuTm1aWEkrSUR4bVpVWjFibU5CSUhSNWNHVTlJbXhwYm1WaGNpSWdjMnh2Y0dVOUlqQXVOaUlnTHo0Z1BDOW1aVU52YlhCdmJtVnVkRlJ5WVc1elptVnlQaUE4Wm1WTlpYSm5aVDRnUEdabFRXVnlaMlZPYjJSbElDOCtJRHhtWlUxbGNtZGxUbTlrWlNCcGJqMGlVMjkxY21ObFIzSmhjR2hwWXlJZ0x6NGdQQzltWlUxbGNtZGxQaUE4TDJacGJIUmxjajRnUEM5a1pXWnpQanh5WldOMElIZzlJalVpSUhrOUlqVWlJSGRwWkhSb1BTSTRORGNpSUdobGFXZG9kRDBpTkRrd0lpQnllRDBpTkRBaUlISjVQU0l6TUNJZ1ptbHNiRDBpZFhKc0tDTm5jbUZrS1NJZ2MzUnliMnRsUFNKaWJHRmpheUlnYzNSeWIydGxMWGRwWkhSb1BTSXhJaUF2UGp4bklHTnNhWEF0Y0dGMGFEMGlkWEpzS0NOeVpXTjBMV05zYVhBcElqNGdQR2NnWm1sc2RHVnlQU0oxY213b0kyUnliM0J6YUdGa2IzY3BJajRnUEhWelpTQm9jbVZtUFNJamJHOW5ieUlnZUQwaUxUWXdNQ0lnZVQwaUxUVXdJaUIzYVdSMGFEMGlNVFV3TUNJZ2FHVnBaMmgwUFNJNE1EQWlJSE4wZVd4bFBTSm1hV3hzT2lCeVpXUTdJRzl3WVdOcGRIazZJREF1TVRVN0lpQXZQaUE4TDJjK0lEd3ZaejQ4YzNabklIWnBaWGRDYjNnOUlqQWdNQ0F5TURBZ01UQXdJaUIzYVdSMGFEMGlNalF3SWlCNFBTSTJNVFVpSUhrOUlpMHhPRFVpSUhOMGVXeGxQU0ptYVd4c09pQWpabVpqWXpFME95QnZjR0ZqYVhSNU9pQXdMamc3SWo0Z1BHY2dabWxzZEdWeVBTSjFjbXdvSTJSeWIzQnphR0ZrYjNjeUtTSStJRHgxYzJVZ2FISmxaajBpSTNKaGFXeGhMV3h2WjI4aUlIZzlJakFpSUhrOUlqQWlJSGRwWkhSb1BTSXhNVEFpSUM4K0lEeDFjMlVnYUhKbFpqMGlJMnh2WjI4aUlIZzlJamMxSWlCNVBTSXhOaUlnZDJsa2RHZzlJakUwTUNJZ2FHVnBaMmgwUFNJM01DSWdMejRnUEM5blBpQThMM04yWno0OGRHVjRkQ0I0UFNJMU1DSWdlVDBpTkRNMUlpQnpkSGxzWlQwaVptOXVkRG9nTVRSd2VDQnpZVzV6TFhObGNtbG1PeUJtYVd4c09pQWpabVpqWXpFME95SStWRTlMUlU0OEwzUmxlSFErUEhSbGVIUWdhV1E5SW1SbFluUnZjaUlnZUQwaU1UTXpJaUI1UFNJME16VWlJSE4wZVd4bFBTSm1iMjUwT2lBeE9IQjRJSE5oYm5NdGMyVnlhV1k3SUdacGJHdzZJQ05tWm1Oak1UUTdJSFJsZUhRdGMyaGhaRzkzT2lBeGNIZ2dNWEI0SURGd2VDQWpNV014WXpGak95QnZjR0ZqYVhSNU9pQXdMams3SWo0eFBDOTBaWGgwUGlBOGRHVjRkQ0I0UFNJMU1DSWdlVDBpTkRZMUlpQnpkSGxzWlQwaVptOXVkRG9nTVRSd2VDQnpZVzV6TFhObGNtbG1PeUJtYVd4c09pQWpabVpqWXpFME95SStSRVZDVkU5U0lFbEVQQzkwWlhoMFBqeDBaWGgwSUdsa1BTSmtaV0owYjNJaUlIZzlJakV6TXlJZ2VUMGlORFkxSWlCemRIbHNaVDBpZEdWNGRDMTBjbUZ1YzJadmNtMDZJSFZ3Y0dWeVkyRnpaVHNnWm05dWREb2dNVGh3ZUNCellXNXpMWE5sY21sbU95Qm1hV3hzT2lBalptWmpZekUwT3lCMFpYaDBMWE5vWVdSdmR6b2dNWEI0SURGd2VDQXhjSGdnSXpGak1XTXhZenNnYjNCaFkybDBlVG9nTUM0NU95SStNREF3TUNBd01EQXdJREF3TURBZ01EQXdNQ0F3TURBd0lEQXdNREFnTURBd01DQXdNREF3SURBd01EQWdNREEyTkR3dmRHVjRkRDRnUEM5emRtYysifQ==");
    }

    function test_AcceptRequestOnEmptyRequest() public {
        vm.prank(bob);
        usd.approve(address(raila), 1 ether);
        vm.expectRevert(Raila.NotHuman.selector);
        vm.prank(bob);
        raila.acceptRequest(2);
    }

    function test_AcceptRequestOnRequestZero() public {
        vm.prank(bob);
        usd.approve(address(raila), 1 ether);
        vm.expectRevert(Raila.NotHuman.selector);
        vm.prank(bob);
        raila.acceptRequest(0);
    }

    function test_AcceptRequestOnCanceledRequest() public {
        vm.prank(alice);
        raila.cancelRequest();
        vm.prank(bob);
        usd.approve(address(raila), 1 ether);
        vm.expectRevert(Raila.NotHuman.selector);
        vm.prank(bob);
        raila.acceptRequest(1);
    }

    function test_AcceptRequestOnActiveLoan() public {
        vm.prank(bob);
        usd.approve(address(raila), 1 ether);
        vm.prank(bob);
        raila.acceptRequest(1);
        vm.prank(bob);
        usd.approve(address(raila), 1 ether);
        vm.expectRevert(Raila.LoanActive.selector);
        vm.prank(bob);
        raila.acceptRequest(1);
    }

    function test_AcceptRequestWithoutEnoughFunds() public {
        vm.prank(bob);
        usd.transfer(eve, 0.9 ether);
        vm.prank(eve);
        usd.approve(address(raila), 1 ether);
        vm.expectRevert(); // not necessarily reverts with NotPaid; most ERC20 revert
        vm.prank(eve);
        raila.acceptRequest(1);
    }

    function test_AcceptRequestWithoutEnoughAllowance() public {
        vm.prank(bob);
        usd.approve(address(raila), 0.9 ether);
        vm.expectRevert(); // not necessarily reverts with NotPaid; most ERC20 revert
        vm.prank(bob);
        raila.acceptRequest(1);
    }

    function test_AcceptingRequestUsesLatestFeeRate() public {
        uint16 currentFeeRate = raila.FEE_RATE();
        vm.prank(bob);
        usd.approve(address(raila), 2 ether);
        vm.prank(bob);
        raila.acceptRequest(1);
        (,,,,,, uint16 feeRate1,,,,) = raila.requests(1);
        vm.assertEq(currentFeeRate, feeRate1);

        vm.prank(governor);
        raila.changeFeeRate(1000);
        vm.prank(eve);
        uint256 newReqId = raila.createRequest(1 ether, INTEREST_RATE_30_YEAR, 2 ether, "");
        vm.assertEq(newReqId, 2);
        vm.prank(bob);
        raila.acceptRequest(2);
        (,,,,,, uint16 feeRate2,,,,) = raila.requests(2);
        vm.assertEq(1000, feeRate2);
    }
}

contract ForgiveDebt is RailaTest {
    IProofOfHumanity poh;
    ERC20 usd;
    Raila raila;

    function setUp() public {
        poh = new MockPoH();
        vm.prank(bob);
        usd = new PolloCoin(100 ether);
        raila = new Raila(governor, treasury, 86400 * 90, INTEREST_RATE_MAX, usd, poh, 500);
        vm.prank(alice);
        raila.createRequest(1 ether, INTEREST_RATE_30_YEAR, 2 ether, "");
        vm.prank(bob);
        usd.approve(address(raila), 1 ether);
        vm.prank(bob);
        raila.acceptRequest(1);
    }

    function test_CreditorCanForgiveDebt() public {
        vm.prank(bob);
        raila.forgiveDebt(1);
    }

    function test_ForgiveDebtLogs() public {
        vm.expectEmit(true, false, false, true, address(raila));
        emit Raila.LoanForgiven(1, 1066830984986877400);
        vm.expectEmit(true, true, true, false, address(raila));
        emit IERC721.Transfer(bob, address(0), 1); // loan nft burn

        vm.prank(bob);
        raila.forgiveDebt(1);
    }

    function test_ForgiveDebtReads() public {
        vm.prank(bob);
        raila.forgiveDebt(1);

        assertEq(raila.borrowerToRequestId(aliceH), 0); // ref must be erased
        // forgiving a request must delete all struct data
        (bytes20 debtor, uint40 createdAtBlock, Raila.RequestStatus status, address creditor, uint40 fundedAt,
        uint40 lastUpdatedAt, uint16 feeRate, UD60x18 interestRatePerSecond,
        uint256 originalDebt, uint256 totalDebt, uint256 defaultThreshold) = raila.requests(1);
        vm.assertEq(debtor, bytes20(address(0)));
        vm.assertEq(createdAtBlock, 0);
        vm.assertEq(uint8(status), uint8(0));
        vm.assertEq(creditor, address(0));
        vm.assertEq(fundedAt, 0);
        vm.assertEq(lastUpdatedAt, 0); 
        vm.assertEq(feeRate, 0);
        vm.assertEq(interestRatePerSecond.unwrap(), 0);
        vm.assertEq(originalDebt, 0);
        vm.assertEq(totalDebt, 0);
        vm.assertEq(defaultThreshold, 0);
    }

    function test_NonCreditorCannotForgive() public {
        vm.expectRevert(Raila.NotCreditor.selector);
        vm.prank(eve);
        raila.forgiveDebt(1);
    }

    function test_GovernorCanForgive() public {
        vm.prank(governor);
        raila.forgiveDebt(1);
    }

    function test_ForgiveTwice() public {
        vm.prank(bob);
        raila.forgiveDebt(1);
        vm.expectRevert(Raila.LoanNotActive.selector);
        vm.prank(bob);
        raila.forgiveDebt(1);
    }

    function test_NotEvenGovernorCanForgiveTwice() public {
        vm.prank(governor);
        raila.forgiveDebt(1);
        vm.expectRevert(Raila.LoanNotActive.selector);
        vm.prank(governor);
        raila.forgiveDebt(1);
    }

    function test_NoForgiveBadIndex() public {
        vm.expectRevert(Raila.LoanNotActive.selector);
        vm.prank(governor);
        raila.forgiveDebt(2);
    }

    function test_ForgiveDebtLongTime() public {
        // when time passes, debt is updated
        vm.warp(block.timestamp + 1000 days);
        vm.expectEmit(true, false, false, true, address(raila));
        emit Raila.LoanForgiven(1, 2051982084767566658);
        vm.expectEmit(true, true, true, false, address(raila));
        emit IERC721.Transfer(bob, address(0), 1); // loan nft burn

        vm.prank(bob);
        raila.forgiveDebt(1);
    }
}

contract PayLoan is RailaTest {
    IProofOfHumanity poh;
    ERC20 usd;
    Raila raila;

    function setUp() public {
        poh = new MockPoH();
        vm.prank(bob);
        usd = new PolloCoin(100 ether);
        raila = new Raila(governor, treasury, 86400 * 90, INTEREST_RATE_MAX, usd, poh, 500);
        vm.prank(alice);
        raila.createRequest(1 ether, INTEREST_RATE_30_YEAR, 2 ether, "");
        vm.prank(bob);
        usd.approve(address(raila), 1 ether);
        vm.prank(bob);
        raila.acceptRequest(1);
    }

    function test_AliceFullyPaysImmediately() public {
        // alice gets all money required and pays instantly with an excess of 0.01 ether
        // she pays original, plus min interest, and gets the excess back.
        vm.prank(bob);
        usd.transfer(alice, 76830984986877400);
        vm.prank(alice);
        usd.approve(address(raila), 1076830984986877400);
        // alice usd => raila
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(alice, address(raila), 1076830984986877400);
        // payment announcement
        vm.expectEmit(true, false, false, true, address(raila));
        emit Raila.LoanRepayment(1, 1066830984986877400, 0);
        // total to creditor (original + most of interest)
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), bob, 1063489435737533530);
        // fees to raila treasury (feeRate * interest)
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), treasury, 3341549249343870);
        // excess back to usd sender
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), alice, 10000000000000000);
        // full payment destroys the loan nft
        vm.expectEmit(true, true, true, false, address(raila));
        emit IERC721.Transfer(bob, address(0), 1);

        vm.prank(alice);
        raila.payLoan(1, 1076830984986877400);

        assertEq(raila.borrowerToRequestId(aliceH), 0); // ref must be erased
        // fully paying a loan must delete all struct data
        (bytes20 debtor, uint40 createdAtBlock, Raila.RequestStatus status, address creditor, uint40 fundedAt,
        uint40 lastUpdatedAt, uint16 feeRate, UD60x18 interestRatePerSecond,
        uint256 originalDebt, uint256 totalDebt, uint256 defaultThreshold) = raila.requests(1);
        vm.assertEq(debtor, bytes20(address(0)));
        vm.assertEq(createdAtBlock, 0);
        vm.assertEq(uint8(status), uint8(0));
        vm.assertEq(creditor, address(0));
        vm.assertEq(fundedAt, 0);
        vm.assertEq(lastUpdatedAt, 0); 
        vm.assertEq(feeRate, 0);
        vm.assertEq(interestRatePerSecond.unwrap(), 0);
        vm.assertEq(originalDebt, 0);
        vm.assertEq(totalDebt, 0);
        vm.assertEq(defaultThreshold, 0);
    }
    // will refrain from checking storage reads to verify loan is destroyed from this point onwards.
    function test_AliceFullyPaysAtMinimumPeriod() public {
        // everything should happen exactly as the test above, despite the time.
        vm.warp(block.timestamp + 86400 * 90);
        vm.prank(bob);
        usd.transfer(alice, 76830984986877400);
        vm.prank(alice);
        usd.approve(address(raila), 1076830984986877400);
        // alice usd => raila
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(alice, address(raila), 1076830984986877400);
        // payment announcement
        vm.expectEmit(true, false, false, true, address(raila));
        emit Raila.LoanRepayment(1, 1066830984986877400, 0);
        // total to creditor (original + most of interest)
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), bob, 1063489435737533530);
        // fees to raila treasury (feeRate * interest)
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), treasury, 3341549249343870);
        // excess back to usd sender
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), alice, 10000000000000000);
        // full payment destroys the loan nft
        vm.expectEmit(true, true, true, false, address(raila));
        emit IERC721.Transfer(bob, address(0), 1);

        vm.prank(alice);
        raila.payLoan(1, 1076830984986877400);
    }

    function test_AliceFullyPaysOneDayAfterMinPeriod() public {
        // numbers are slightly bigger to account for 1 day of extra interest
        vm.warp(block.timestamp + 86400 * 91);
        vm.prank(bob);
        usd.transfer(alice, 76830984986877400);
        vm.prank(alice);
        usd.approve(address(raila), 1076830984986877400);
        // alice usd => raila
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(alice, address(raila), 1076830984986877400);
        // payment announcement
        vm.expectEmit(true, false, false, true, address(raila));
        emit Raila.LoanRepayment(1, 1067598105382081556, 0);
        // total to creditor (original + most of interest)
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), bob, 1064218200112977479);
        // fees to raila treasury (feeRate * interest)
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), treasury, 3379905269104077);
        // excess back to usd sender
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), alice, 9232879604795844);
        // full payment destroys the loan nft
        vm.expectEmit(true, true, true, false, address(raila));
        emit IERC721.Transfer(bob, address(0), 1);

        vm.prank(alice);
        raila.payLoan(1, 1076830984986877400);
    }

    function test_AliceOnlyPaysOriginalDebt() public {
        vm.prank(alice);
        usd.approve(address(raila), 1000000000000000000);
        // alice usd => raila
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(alice, address(raila), 1000000000000000000);
        // payment announcement. there's debt remaining
        vm.expectEmit(true, false, false, true, address(raila));
        emit Raila.LoanRepayment(1, 1000000000000000000, 66830984986877400);
        // total to creditor (original), no interest debt paid.
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), bob, 1000000000000000000);
        // no fees to raila treasury
        // no excess back to usd sender
        // loan was not extinguished
        vm.prank(alice);
        raila.payLoan(1, 1000000000000000000);
        // loan was not extinguished, so ref must remain
        assertEq(raila.borrowerToRequestId(aliceH), 1);
        // loan remains, but original debt has been paid
        (bytes20 debtor, uint40 createdAtBlock, Raila.RequestStatus status, address creditor, uint40 fundedAt,
        uint40 lastUpdatedAt, uint16 feeRate, UD60x18 interestRatePerSecond,
        uint256 originalDebt, uint256 totalDebt, uint256 defaultThreshold) = raila.requests(1);
        vm.assertEq(debtor, aliceH);
        vm.assertEq(createdAtBlock, block.number);
        vm.assertEq(uint8(status), uint8(1));
        vm.assertEq(creditor, bob);
        vm.assertEq(fundedAt, block.timestamp);
        // payment before the min interest period, so lastUpdatedAt is min period + fundedAt
        vm.assertEq(lastUpdatedAt, block.timestamp + 86400 * 90); 
        vm.assertEq(feeRate, 500);
        vm.assertEq(interestRatePerSecond.unwrap(), INTEREST_RATE_30_YEAR.unwrap());
        vm.assertEq(originalDebt, 0); // fully paid
        vm.assertEq(totalDebt, 66830984986877400);
        vm.assertEq(defaultThreshold, 2 ether);
    }

    function test_AlicePaysOriginalDebtPartially() public {
        vm.prank(alice);
        usd.approve(address(raila), 0.01 ether);
        // alice usd => raila
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(alice, address(raila), 0.01 ether);
        // payment announcement. there's debt remaining
        vm.expectEmit(true, false, false, true, address(raila));
        emit Raila.LoanRepayment(1, 0.01 ether, 1056830984986877400);
        // total to creditor (original), no interest debt paid.
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), bob, 0.01 ether);
        // no fees to raila treasury
        // no excess back to usd sender
        // loan was not extinguished
        vm.prank(alice);
        raila.payLoan(1, 0.01 ether);
        // loan was not extinguished, so ref must remain
        assertEq(raila.borrowerToRequestId(aliceH), 1);
        // loan remains, only some original debt has been paid
        (bytes20 debtor, uint40 createdAtBlock, Raila.RequestStatus status, address creditor, uint40 fundedAt,
        uint40 lastUpdatedAt, uint16 feeRate, UD60x18 interestRatePerSecond,
        uint256 originalDebt, uint256 totalDebt, uint256 defaultThreshold) = raila.requests(1);
        vm.assertEq(debtor, aliceH);
        vm.assertEq(createdAtBlock, block.number);
        vm.assertEq(uint8(status), uint8(1));
        vm.assertEq(creditor, bob);
        vm.assertEq(fundedAt, block.timestamp);
        // payment before the min interest period, so lastUpdatedAt is min period + fundedAt
        vm.assertEq(lastUpdatedAt, block.timestamp + 86400 * 90); 
        vm.assertEq(feeRate, 500);
        vm.assertEq(interestRatePerSecond.unwrap(), INTEREST_RATE_30_YEAR.unwrap());
        vm.assertEq(originalDebt, 0.99 ether); // fully paid
        vm.assertEq(totalDebt, 1056830984986877400);
        vm.assertEq(defaultThreshold, 2 ether);
    }

    function test_OriginalDebtDoesNotGrow() public {
        vm.warp(block.timestamp + 1000 days); // few years pass, but original debt is stuck.
        vm.prank(alice);
        usd.approve(address(raila), 0.01 ether);
        vm.prank(alice);
        raila.payLoan(1, 0.01 ether);
        (,,,,,,,,uint256 originalDebt,,) = raila.requests(1);
        vm.assertEq(originalDebt, 0.99 ether);
    }

    function test_AlicePaysOriginalAndSomeInterest() public {
        vm.prank(bob);
        usd.transfer(alice, 0.01 ether);
        vm.prank(alice);
        usd.approve(address(raila), 1.01 ether);
        vm.prank(alice);
        // payment announcement
        vm.expectEmit(true, false, false, true, address(raila));
        emit Raila.LoanRepayment(1, 1.01 ether, 56830984986877400);
        // total to creditor (original + most of interest)
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), bob, 1009500000000000000);
        // fees to raila treasury (feeRate * interest)
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), treasury, 500000000000000);
        raila.payLoan(1, 1.01 ether);

        (,,,,,,,,uint256 originalDebt, uint256 totalDebt,) = raila.requests(1);
        vm.assertEq(originalDebt, 0 ether);
        vm.assertEq(totalDebt, 56830984986877400);
    }

    function test_PayingDebtInBatches() public {
        // realistic amortization of debt in a few batches separated by time
        vm.prank(alice);
        usd.approve(address(raila), 100 ether);
        // batch 1
        uint256 originTime = block.timestamp;
        vm.warp(block.timestamp + 100 days);
        vm.prank(bob);
        usd.transfer(alice, 0.5 ether);
        vm.prank(alice);
        raila.payLoan(1, 0.5 ether);
        assertEq(raila.borrowerToRequestId(aliceH), 1); // loan still alive
        (,,,,uint256 fundedAt1,uint256 lastUpdated1,,,uint256 originalDebt1,uint256 totalDebt1,) = raila.requests(1);
        vm.assertEq(fundedAt1, originTime);
        vm.assertEq(lastUpdated1, originTime + 100 days);
        vm.assertLt(fundedAt1, lastUpdated1); // invariant: while loan, funded < lastUpdated
        vm.assertEq(originalDebt1, 0.5 ether);
        vm.assertEq(totalDebt1, 574527059006372707);
        vm.assertLt(originalDebt1, totalDebt1); // invariant: while loan, ogd < totd
        // batch 2
        vm.warp(block.timestamp + 100 days);
        vm.prank(bob);
        usd.transfer(alice, 0.5 ether);
        vm.prank(alice);
        raila.payLoan(1, 0.5 ether);
        assertEq(raila.borrowerToRequestId(aliceH), 1); // loan still alive
        (,,,,uint256 fundedAt2,uint256 lastUpdated2,,,uint256 originalDebt2,uint256 totalDebt2,) = raila.requests(1);
        vm.assertEq(fundedAt2, originTime);
        vm.assertEq(lastUpdated2, originTime + 200 days);
        vm.assertEq(originalDebt2, 0);
        vm.assertEq(totalDebt2, 117344871033698420);
        // batch 3
        vm.warp(block.timestamp + 100 days);
        vm.prank(bob);
        usd.transfer(alice, 0.5 ether);
        // lets make sure she gets the excess
        // alice usd => raila
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(alice, address(raila), 0.5 ether);
        // payment announcement
        vm.expectEmit(true, false, false, true, address(raila));
        emit Raila.LoanRepayment(1, 126090239161322057, 0);
        // total to creditor
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), bob, 119785727203255955);
        // fees to raila treasury (feeRate * interest)
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), treasury, 6304511958066102);
        // excess back to usd sender
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), alice, 373909760838677943);
        // full payment destroys the loan nft
        vm.expectEmit(true, true, true, false, address(raila));
        emit IERC721.Transfer(bob, address(0), 1);

        vm.prank(alice);
        raila.payLoan(1, 0.5 ether);
        assertEq(raila.borrowerToRequestId(aliceH), 0); // loan now dead
        (,,,,,,,,uint256 originalDebt3,uint256 totalDebt3,) = raila.requests(1);
        vm.assertEq(originalDebt3, 0);
        vm.assertEq(totalDebt3, 0);
        // treasury should've obtained some money, ~6 mETH
        vm.assertLe(0.006 ether, usd.balanceOf(treasury));
    }

    function test_ThirdPartyCanPayLoan() public {
        vm.prank(bob);
        usd.transfer(eve, 2 ether);
        vm.prank(eve);
        usd.approve(address(raila), 2 ether);
        vm.prank(eve);
        raila.payLoan(1, 2 ether);
        assertEq(raila.borrowerToRequestId(aliceH), 0); // loan now dead
    }

    function test_NoPayWithoutApproval() public {
        vm.prank(bob);
        usd.transfer(eve, 2 ether);
        vm.expectRevert();
        vm.prank(eve);
        raila.payLoan(1, 2 ether);
    }

    function test_NoPayLoanDoesNotExist() public {
        vm.prank(bob);
        usd.transfer(eve, 2 ether);
        vm.prank(eve);
        usd.approve(address(raila), 2 ether);
        vm.expectRevert(Raila.LoanNotActive.selector);
        vm.prank(eve);
        raila.payLoan(2, 2 ether);
    }

    function test_NoPayLoanCompleted() public {
        vm.prank(bob);
        usd.transfer(eve, 2 ether);
        vm.prank(eve);
        usd.approve(address(raila), 2 ether);
        vm.prank(eve);
        raila.payLoan(1, 2 ether);
        // loan is now paid, so this payment must fail
        vm.expectRevert(Raila.LoanNotActive.selector);
        vm.prank(eve);
        raila.payLoan(1, 0.1 ether);
    }

    function test_CanPayWithZero() public {
        vm.prank(eve);
        raila.payLoan(1, 0);
    }

    function test_PayingWithZeroCanUpdateValues() public {
        // paying 0 at time 0 is a noop
        vm.prank(eve);
        raila.payLoan(1, 0);
        uint256 originTime = block.timestamp;
        (,,,,uint256 fundedAt0,uint256 lastUpdated0,,,uint256 originalDebt0,uint256 totalDebt0,) = raila.requests(1);
        vm.assertEq(fundedAt0, originTime);
        vm.assertEq(lastUpdated0, originTime + 86400 * 90);
        vm.assertEq(originalDebt0, 1 ether);
        vm.assertEq(totalDebt0, 1066830984986877400);
        // paying 0 at time min_period is a noop
        vm.warp(block.timestamp + 86400 * 90);
        (,,,,uint256 fundedAt1,uint256 lastUpdated1,,,uint256 originalDebt1,uint256 totalDebt1,) = raila.requests(1);
        vm.assertEq(fundedAt1, originTime);
        vm.assertEq(lastUpdated1, originTime + 86400 * 90);
        vm.assertEq(originalDebt1, 1 ether);
        vm.assertEq(totalDebt1, 1066830984986877400);
        // paying 0 at time after min_period mutates lastUpdated and the interest
        vm.warp(block.timestamp + 1000 days);
        vm.prank(eve);
        raila.payLoan(1, 0);
        (,,,,uint256 fundedAt2,uint256 lastUpdated2,,,uint256 originalDebt2,uint256 totalDebt2,) = raila.requests(1);
        vm.assertEq(fundedAt2, originTime);
        vm.assertEq(lastUpdated2, originTime + 86400 * 90 + 1000 days);
        vm.assertEq(originalDebt2, 1 ether);
        vm.assertEq(totalDebt2, 2189118068668009296); // has increased.
    }
}

contract NFTStuff is RailaTest {
    IProofOfHumanity poh;
    ERC20 usd;
    Raila raila;

    function setUp() public {
        poh = new MockPoH();
        vm.prank(bob);
        usd = new PolloCoin(100 ether);
        raila = new Raila(governor, treasury, 86400 * 90, INTEREST_RATE_MAX, usd, poh, 500);
        vm.prank(alice);
        raila.createRequest(1 ether, INTEREST_RATE_30_YEAR, 2 ether, "");
        vm.prank(bob);
        usd.approve(address(raila), 1 ether);
        vm.prank(bob);
        raila.acceptRequest(1);
    }

    function test_Approve() public {
        vm.prank(bob);
        raila.approve(charlie, 1);
    }

    function test_ApproveLogs() public {
        vm.expectEmit(true, true, true, false, address(raila));
        emit IERC721.Approval(bob, charlie, 1);
        vm.prank(bob);
        raila.approve(charlie, 1);
    }

    function test_ApproveReads() public {
        vm.prank(bob);
        raila.approve(charlie, 1);
        vm.assertEq(raila.getApproved(1), charlie);
        // creditor is not yet charlie, still bob
        (,,,address creditor,,,,,,,) = raila.requests(1);
        vm.assertEq(creditor, bob);
        // equivalent
        vm.assertEq(raila.ownerOf(1), bob);
    }

    function test_EveCannotApprove() public {
        vm.expectRevert(Raila.NotCreditor.selector);
        vm.prank(eve);
        raila.approve(charlie, 1);
    }

    function test_ApproveForAll() public {
        vm.prank(bob);
        raila.setApprovalForAll(charlie, true);
    }

    function test_ApproveForAllLogs() public {
        vm.expectEmit(true, true, false, true, address(raila));
        emit IERC721.ApprovalForAll(bob, charlie, true);
        vm.prank(bob);
        raila.setApprovalForAll(charlie, true);
    }

    function test_ApproveForAllReads() public {
        vm.prank(bob);
        raila.setApprovalForAll(charlie, true);
        vm.assertEq(raila.isApprovedForAll(bob, charlie), true);
        vm.assertEq(raila.isApprovedForAll(charlie, bob), false); // not other way around
    }

    function test_TransferFrom() public {
        vm.prank(bob);
        raila.transferFrom(bob, charlie, 1);
    }

    function test_TransferFromLogs() public {
        vm.expectEmit(true, true, true, false, address(raila));
        emit IERC721.Transfer(bob, charlie, 1);
        vm.prank(bob);
        raila.transferFrom(bob, charlie, 1);
    }

    function test_TransferFromReads() public {
        vm.prank(bob);
        raila.transferFrom(bob, charlie, 1);
        vm.assertEq(raila.ownerOf(1), charlie);
    }

    function test_TransferFromApproval() public {
        // eve cannot seize loan
        vm.expectRevert(Raila.NotApproved.selector);
        vm.prank(eve);
        raila.transferFrom(bob, charlie, 1);
        // charlie can, if bob approves him
        vm.prank(bob);
        raila.approve(charlie, 1);
        vm.prank(charlie);
        raila.transferFrom(bob, charlie, 1);
        // bounce it back to bob, then try to transfer it again. approval was consumed.
        vm.prank(charlie);
        raila.transferFrom(charlie, bob, 1);
        vm.expectRevert(Raila.NotApproved.selector);
        vm.prank(charlie);
        raila.transferFrom(bob, charlie, 1);
        // now use approveForAll, charlie will be able to move it as long as held by bob
        vm.prank(bob);
        raila.setApprovalForAll(charlie, true);
        vm.prank(charlie);
        raila.transferFrom(bob, charlie, 1);
        vm.prank(charlie);
        raila.transferFrom(charlie, bob, 1);
        vm.prank(charlie);
        raila.transferFrom(bob, eve, 1);
        // but not if held by eve, because eve does not have approvalForAll to charlie
        vm.expectRevert(Raila.NotApproved.selector);
        vm.prank(charlie);
        raila.transferFrom(eve, bob, 1);
        // seeing charlie negligence, bob removes his approvalForAll
        vm.expectEmit(true, true, false, true, address(raila));
        emit IERC721.ApprovalForAll(bob, charlie, false);
        vm.prank(bob);
        raila.setApprovalForAll(charlie, false);
        vm.assertEq(raila.isApprovedForAll(bob, charlie), false);
        // eve plays nice and gives it back to bob. once charlie has no approvalForAll, he can no longer seize
        vm.prank(eve);
        raila.transferFrom(eve, bob, 1);
        vm.expectRevert(Raila.NotApproved.selector);
        vm.prank(charlie);
        raila.transferFrom(bob, charlie, 1);
    }

    function test_CannotTransferToZero() public {
        vm.expectRevert(Raila.ERC721InvalidReceiver.selector);
        vm.prank(bob);
        raila.transferFrom(bob, address(0), 1);
    }

    function test_SafeTransferFrom() public {
        vm.prank(bob);
        raila.safeTransferFrom(bob, charlie, 1);
    }

    function test_SafeTransferFromData() public {
        vm.prank(bob);
        raila.safeTransferFrom(bob, charlie, 1, "data");
    }

    function test_SafeTransferToEmptyReceiver() public {
        EmptyReceiver receiver = new EmptyReceiver();
        vm.expectRevert(Raila.ERC721InvalidReceiver.selector);
        vm.prank(bob);
        raila.safeTransferFrom(bob, address(receiver), 1, "data");
    }
}

// misc checks:
// 2 loans with equal ogd and distinct interestRates grow at different speeds