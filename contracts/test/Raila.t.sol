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

contract MockPoH is IProofOfHumanity {
    function humanityOf(address owner) public pure returns (bytes20) {
        if (owner == address(1337)) return bytes20(address(69)); // alice
        if (owner == address(666)) return bytes20(address(42)); // eve
        else return bytes20(address(0));
    }
    function boundTo(bytes20 _humanityId) public pure returns (address) {
        if (_humanityId == bytes20(address(69))) return address(1337); // alice
        if (_humanityId == bytes20(address(42))) return address(666); // eve
        else return address(0);
    }
}

contract PolloCoin is ERC20 {
    constructor(uint256 supply) ERC20("PolloCoin", "CAW") {
        _mint(msg.sender, supply);
    }
}

contract Constructor is Test {
    IProofOfHumanity poh;
    ERC20 usd;
    Raila raila;

    function setUp() public {
        vm.prank(address(777));
        poh = new MockPoH();
        usd = new PolloCoin(1e18);
    }

    function test_ConstructorSetsVariables() public {
        raila = new Raila(address(1000), address(1000), 86400 * 90, usd, poh, 500);
        assertEq(raila.GOVERNOR(), address(1000));
        assertEq(raila.TREASURY(), address(1000));
        assertEq(raila.MINIMUM_INTEREST_PERIOD(), 86400 * 90);
        assertEq(address(raila.USD()), address(usd));
        assertEq(address(raila.PROOF_OF_HUMANITY()), address(poh));
        assertEq(raila.FEE_RATE(), 500);
    }

    function test_ChangeGovernor() public {
        raila = new Raila(address(1000), address(1000), 86400 * 90, usd, poh, 500);
        vm.prank(address(1000));
        raila.changeGovernor(address(1001));
        assertEq(raila.GOVERNOR(), address(1001));
    }

    function testFail_ChangeGovernorIntruder() public {
        raila = new Raila(address(1000), address(1000), 86400 * 90, usd, poh, 500);
        vm.prank(address(666));
        raila.changeGovernor(address(1001));
    }

    function test_ChangeTreasury() public {
        raila = new Raila(address(1000), address(1000), 86400 * 90, usd, poh, 500);
        vm.prank(address(1000));
        raila.changeTreasury(address(1001));
        assertEq(raila.TREASURY(), address(1001));
    }

    function testFail_ChangeTreasuryIntruder() public {
        raila = new Raila(address(1000), address(1000), 86400 * 90, usd, poh, 500);
        vm.prank(address(666));
        raila.changeTreasury(address(1001));
    }

    function test_ChangeFeeRate() public {
        raila = new Raila(address(1000), address(1000), 86400 * 90, usd, poh, 500);
        vm.prank(address(1000));
        raila.changeFeeRate(100);
        assertEq(raila.FEE_RATE(), 100);
    }

    function testFail_ChangeFeeRateIntruder() public {
        raila = new Raila(address(1000), address(1000), 86400 * 90, usd, poh, 500);
        vm.prank(address(666));
        raila.changeFeeRate(100);
    }

    function test_ChangeMinInterestPeriod() public {
        raila = new Raila(address(1000), address(1000), 86400 * 90, usd, poh, 500);
        vm.prank(address(1000));
        raila.changeMinimumInterestPeriod(60 days);
        assertEq(raila.MINIMUM_INTEREST_PERIOD(), 60 days);
    }

    function testFail_ChangeMinInterestPeriodIntruder() public {
        vm.prank(address(666));
        raila.changeMinimumInterestPeriod(60 days);
    }
}

contract CreateRequest is Test {
    IProofOfHumanity poh;
    ERC20 usd;
    Raila raila;

    uint256 constant INTEREST_RATE_30_YEAR = 1000000008319516200; 

    function setUp() public {
        poh = new MockPoH();
        usd = new PolloCoin(1e18);
        raila = new Raila(address(1000), address(1000), 86400 * 90, usd, poh, 500);
    }

    function test_RequestLogs() public {
        vm.prank(address(1337));
        vm.expectEmit(true, true, false, true);
        emit Raila.RequestCreation(bytes20(address(69)), 1, "");
        raila.createRequest(1 ether, UD60x18.wrap(INTEREST_RATE_30_YEAR), 2 ether, "");
    }

    function test_RequestReads() public {
        vm.prank(address(1337));
        raila.createRequest(1 ether, UD60x18.wrap(INTEREST_RATE_30_YEAR), 2 ether, "");
        // must mutate requestCounter, add reference borrower => request, and request data
        assertEq(raila.lastRequestId(), 1);
        assertEq(raila.borrowerToRequestId(bytes20(address(69))), 1);

        (bytes20 debtor, uint40 createdAtBlock, Raila.RequestStatus status, address creditor, uint40 fundedAt,
        uint40 lastUpdatedAt, uint16 feeRate, UD60x18 interestRatePerSecond,
        uint256 originalDebt, uint256 totalDebt, uint256 defaultThreshold) = raila.requests(1);
        vm.assertEq(debtor, bytes20(address(69)));
        vm.assertEq(createdAtBlock, block.number);
        vm.assertEq(uint8(status), uint8(Raila.RequestStatus.Open));
        vm.assertEq(creditor, address(0));
        vm.assertEq(fundedAt, 0); // wasn't funded yet
        vm.assertEq(lastUpdatedAt, 0); 
        vm.assertEq(feeRate, 0); // fee rate is not set here, but on acceptRequest
        vm.assertEq(interestRatePerSecond.unwrap(), INTEREST_RATE_30_YEAR);
        vm.assertEq(originalDebt, 1 ether);
        vm.assertEq(totalDebt, 0);
        vm.assertEq(defaultThreshold, 2 ether);
    }

    function test_RequestZeroDoesNotExistAlwaysContainsEmptyData() public {
        vm.prank(address(1337));
        // create a request for good measure, ensure it won't overwrite it
        raila.createRequest(1 ether, UD60x18.wrap(INTEREST_RATE_30_YEAR), 2 ether, "");
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

    function testFail_RequesterMustBeHuman() public {
        vm.prank(address(1336));
        raila.createRequest(1 ether, UD60x18.wrap(INTEREST_RATE_30_YEAR), 2 ether, "");
    }

    function test_RequesterMustBeHuman() public {
        vm.prank(address(1337));
        raila.createRequest(1 ether, UD60x18.wrap(INTEREST_RATE_30_YEAR), 2 ether, "");
    }

    function testFail_MaxOneRequestPerHuman() public {
        vm.prank(address(1337));
        raila.createRequest(1 ether, UD60x18.wrap(INTEREST_RATE_30_YEAR), 2 ether, "");
        raila.createRequest(1 ether, UD60x18.wrap(INTEREST_RATE_30_YEAR), 2 ether, "");
    }

    function testFail_StartingOwedAmountMustBeUnderDefaultsAt() public {
        vm.prank(address(1337));
        raila.createRequest(1 ether, UD60x18.wrap(INTEREST_RATE_30_YEAR), 1 ether, "");
    }

    function testFail_StartingOwedAmountMustBeUnderDefaultsAtInterestIncluded() public {
        vm.prank(address(1337));
        raila.createRequest(1 ether, UD60x18.wrap(INTEREST_RATE_30_YEAR), 1.01 ether, "");
    }

    // just checking close cases that might break 
    function testFail_StartingOwedAmountBarelyDefaultsAtInterestIncluded() public {
        vm.prank(address(1337));
        raila.createRequest(1 ether, UD60x18.wrap(INTEREST_RATE_30_YEAR), 1.06683 ether, "");
    }

    // just checking a close case that might break 
    function test_StartingOwedAmountBarelyNotDefaultsAtInterestIncluded() public {
        vm.prank(address(1337));
        raila.createRequest(1 ether, UD60x18.wrap(INTEREST_RATE_30_YEAR), 1.06684 ether, "");
    }

    // intended: NOOPs, interfaces/subgraph will hide useless logs
    function test_RequesterCanRequestZero() public {
        vm.prank(address(1337));
        raila.createRequest(0, UD60x18.wrap(INTEREST_RATE_30_YEAR), 1 ether, "");
    }

    // although if the defaultsAt is also zero it won't allow it
    function testFail_RequestOfZeroFailsWithZeroDefaultsAt() public {
        vm.prank(address(1337));
        raila.createRequest(0, UD60x18.wrap(INTEREST_RATE_30_YEAR), 0, "");
    }

    // intended: the user can condemn themselves to infinite debt
    function test_RequesterInsaneInterest() public {
        vm.prank(address(1337));
        uint256 INTEREST_RATE_OVER_50000_YEAR = 1000000200000000000;
        raila.createRequest(1 ether, UD60x18.wrap(INTEREST_RATE_OVER_50000_YEAR), 20 ether, "");
    }
}

contract CancelRequest is Test {
    IProofOfHumanity poh;
    ERC20 usd;
    Raila raila;

    uint256 constant INTEREST_RATE_30_YEAR = 1000000008319516200;

    function setUp() public {
        poh = new MockPoH();
        vm.prank(address(777));
        usd = new PolloCoin(100 ether);
        raila = new Raila(address(1000), address(1000), 86400 * 90, usd, poh, 500);
        vm.prank(address(1337));
        raila.createRequest(1 ether, UD60x18.wrap(INTEREST_RATE_30_YEAR), 2 ether, "");
        // request will be at 1
    }

    function test_AliceCancelsHerRequest() public {
        vm.prank(address(1337));
        raila.cancelRequest();
    }

    function test_CancelRequestLogs() public {
        vm.prank(address(1337));
        vm.expectEmit(true, false, false, true);
        emit Raila.RequestCanceled(1);
        raila.cancelRequest();
    }

    function test_CancelRequestReads() public {
        vm.prank(address(1337));
        raila.cancelRequest();

        assertEq(raila.lastRequestId(), 1); // had incremented
        assertEq(raila.borrowerToRequestId(bytes20(address(69))), 0); // ref must be erased

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

    function testFail_NonHumanCannotCancelRequest() public {
        vm.prank(address(1336));
        raila.cancelRequest();
    }

    function testFail_EveCannotCancelRequest() public {
        vm.prank(address(666));
        raila.cancelRequest();
    }

    function testFail_CannotCancelRequestIfLoanBegan() public {
        vm.prank(address(777));
        usd.approve(address(raila), 1 ether);
        vm.prank(address(777));
        raila.acceptRequest(1);

        vm.prank(address(1337));
        raila.cancelRequest();
    }
}

contract AcceptRequest is Test {
    IProofOfHumanity poh;
    ERC20 usd;
    Raila raila;

    uint256 constant INTEREST_RATE_30_YEAR = 1000000008319516200;

    function setUp() public {
        poh = new MockPoH();
        vm.prank(address(777));
        usd = new PolloCoin(100 ether);
        raila = new Raila(address(1000), address(1000), 86400 * 90, usd, poh, 500);
        vm.prank(address(1337));
        raila.createRequest(1 ether, UD60x18.wrap(INTEREST_RATE_30_YEAR), 2 ether, "");
        // request will be at 1
    }

    function test_CreditorCanAcceptRequest() public {
        vm.prank(address(777));
        usd.approve(address(raila), 1 ether);
        vm.prank(address(777));
        raila.acceptRequest(1);
    }

    function test_AcceptRequestLogs() public {
        vm.prank(address(777));
        usd.approve(address(raila), 1 ether);
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(777), address(1337), 1 ether);
        vm.expectEmit(true, true, true, false, address(raila));
        emit IERC721.Transfer(address(0), address(777), 1); // loan nft mint
        vm.prank(address(777));
        raila.acceptRequest(1);
    }

    function test_AcceptRequestReads() public {
        vm.prank(address(777));
        usd.approve(address(raila), 1 ether);
        vm.prank(address(777));
        raila.acceptRequest(1);

        (bytes20 debtor, uint40 createdAtBlock, Raila.RequestStatus status, address creditor, uint40 fundedAt,
        uint40 lastUpdatedAt, uint16 feeRate, UD60x18 interestRatePerSecond,
        uint256 originalDebt, uint256 totalDebt, uint256 defaultThreshold) = raila.requests(1);
        vm.assertEq(debtor, bytes20(address(69)));
        vm.assertEq(createdAtBlock, block.number);
        vm.assertEq(uint8(status), uint8(1));
        vm.assertEq(creditor, address(777));
        vm.assertEq(fundedAt, block.timestamp);
        vm.assertEq(lastUpdatedAt, block.timestamp + 86400 * 90); 
        vm.assertEq(feeRate, 500);
        vm.assertEq(interestRatePerSecond.unwrap(), INTEREST_RATE_30_YEAR);
        vm.assertEq(originalDebt, 1 ether);
        vm.assertEq(totalDebt, 1066830984986877400); // precompounded for minimum period
        vm.assertEq(defaultThreshold, 2 ether);

        vm.assertEq(raila.balanceOf(address(777)), 1);

        // check new balances
        vm.assertEq(usd.balanceOf(address(777)), 99 ether); // creditor started 100 but lost 1
        vm.assertEq(usd.allowance(address(777), address(raila)), 0 ether); // spent allowance
        vm.assertEq(usd.balanceOf(address(1337)), 1 ether); // alice got 1
    }

    function testFail_AcceptRequestOnEmptyRequest() public {
        vm.prank(address(777));
        usd.approve(address(raila), 1 ether);
        vm.prank(address(777));
        raila.acceptRequest(2);
    }

    function testFail_AcceptRequestOnRequestZero() public {
        vm.prank(address(777));
        usd.approve(address(raila), 1 ether);
        vm.prank(address(777));
        raila.acceptRequest(0);
    }

    function testFail_AcceptRequestOnCanceledRequest() public {
        vm.prank(address(1337));
        raila.cancelRequest();
        vm.prank(address(777));
        usd.approve(address(raila), 1 ether);
        vm.prank(address(777));
        raila.acceptRequest(1);
    }

    function testFail_AcceptRequestOnActiveLoan() public {
        vm.prank(address(777));
        usd.approve(address(raila), 1 ether);
        vm.prank(address(777));
        raila.acceptRequest(1);
        vm.prank(address(777));
        usd.approve(address(raila), 1 ether);
        vm.prank(address(777));
        raila.acceptRequest(1);
    }

    function testFail_AcceptRequestWithoutEnoughFunds() public {
        vm.prank(address(777));
        usd.transfer(address(778), 0.9 ether);
        vm.prank(address(778));
        usd.approve(address(raila), 1 ether);
        vm.prank(address(778));
        raila.acceptRequest(1);
    }

    function testFail_AcceptRequestWithoutEnoughAllowance() public {
        vm.prank(address(777));
        usd.approve(address(raila), 0.9 ether);
        vm.prank(address(777));
        raila.acceptRequest(1);
    }
}

contract ForgiveDebt is Test {
    IProofOfHumanity poh;
    ERC20 usd;
    Raila raila;

    uint256 constant INTEREST_RATE_30_YEAR = 1000000008319516200;

    function setUp() public {
        poh = new MockPoH();
        vm.prank(address(777));
        usd = new PolloCoin(100 ether);
        raila = new Raila(address(1000), address(1000), 86400 * 90, usd, poh, 500);
        vm.prank(address(1337));
        raila.createRequest(1 ether, UD60x18.wrap(INTEREST_RATE_30_YEAR), 2 ether, "");
        vm.prank(address(777));
        usd.approve(address(raila), 1 ether);
        vm.prank(address(777));
        raila.acceptRequest(1);
    }

    function test_CreditorCanForgiveDebt() public {
        vm.prank(address(777));
        raila.forgiveDebt(1);
    }

    function test_ForgiveDebtLogs() public {
        vm.expectEmit(true, false, false, true, address(raila));
        emit Raila.LoanForgiven(1, 1066830984986877400);
        vm.expectEmit(true, true, true, false, address(raila));
        emit IERC721.Transfer(address(777), address(0), 1); // loan nft burn

        vm.prank(address(777));
        raila.forgiveDebt(1);
    }

    function test_ForgiveDebtReads() public {
        vm.prank(address(777));
        raila.forgiveDebt(1);

        assertEq(raila.borrowerToRequestId(bytes20(address(69))), 0); // ref must be erased
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

    function testFail_NonCreditorCannotForgive() public {
        vm.prank(address(666));
        raila.forgiveDebt(1);
    }

    function test_GovernorCanForgive() public {
        vm.prank(address(1000));
        raila.forgiveDebt(1);
    }

    function testFail_ForgiveTwice() public {
        vm.prank(address(777));
        raila.forgiveDebt(1);
        raila.forgiveDebt(1);
    }

    function testFail_NotEvenGovernorCanForgiveTwice() public {
        vm.prank(address(1000));
        raila.forgiveDebt(1);
        raila.forgiveDebt(1);
    }

    function testFail_NoForgiveBadIndex() public {
        vm.prank(address(1000));
        raila.forgiveDebt(2);
    }

    function test_ForgiveDebtLongTime() public {
        // when time passes, debt is updated
        vm.warp(block.timestamp + 1000 days);
        vm.expectEmit(true, false, false, true, address(raila));
        emit Raila.LoanForgiven(1, 2051982084767566658);
        vm.expectEmit(true, true, true, false, address(raila));
        emit IERC721.Transfer(address(777), address(0), 1); // loan nft burn

        vm.prank(address(777));
        raila.forgiveDebt(1);
    }
}

contract PayLoan is Test {
    IProofOfHumanity poh;
    ERC20 usd;
    Raila raila;

    uint256 constant INTEREST_RATE_30_YEAR = 1000000008319516200;

    function setUp() public {
        poh = new MockPoH();
        vm.prank(address(777));
        usd = new PolloCoin(100 ether);
        raila = new Raila(address(1000), address(1000), 86400 * 90, usd, poh, 500);
        vm.prank(address(1337));
        raila.createRequest(1 ether, UD60x18.wrap(INTEREST_RATE_30_YEAR), 2 ether, "");
        vm.prank(address(777));
        usd.approve(address(raila), 1 ether);
        vm.prank(address(777));
        raila.acceptRequest(1);
    }

    function test_AliceFullyPaysImmediately() public {
        // alice gets all money required and pays instantly with an excess of 0.01 ether
        // she pays original, plus min interest, and gets the excess back.
        vm.prank(address(777));
        usd.transfer(address(1337), 76830984986877400);
        vm.prank(address(1337));
        usd.approve(address(raila), 1076830984986877400);
        // alice usd => raila
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(1337), address(raila), 1076830984986877400);
        // payment announcement
        vm.expectEmit(true, false, false, true, address(raila));
        emit Raila.LoanRepayment(1, 1066830984986877400, 0);
        // total to creditor (original + most of interest)
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), address(777), 1063489435737533530);
        // fees to raila treasury (feeRate * interest)
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), address(1000), 3341549249343870);
        // excess back to usd sender
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), address(1337), 10000000000000000);
        // full payment destroys the loan nft
        vm.expectEmit(true, true, true, false, address(raila));
        emit IERC721.Transfer(address(777), address(0), 1);

        vm.prank(address(1337));
        raila.payLoan(1, 1076830984986877400);

        assertEq(raila.borrowerToRequestId(bytes20(address(69))), 0); // ref must be erased
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
        vm.prank(address(777));
        usd.transfer(address(1337), 76830984986877400);
        vm.prank(address(1337));
        usd.approve(address(raila), 1076830984986877400);
        // alice usd => raila
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(1337), address(raila), 1076830984986877400);
        // payment announcement
        vm.expectEmit(true, false, false, true, address(raila));
        emit Raila.LoanRepayment(1, 1066830984986877400, 0);
        // total to creditor (original + most of interest)
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), address(777), 1063489435737533530);
        // fees to raila treasury (feeRate * interest)
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), address(1000), 3341549249343870);
        // excess back to usd sender
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), address(1337), 10000000000000000);
        // full payment destroys the loan nft
        vm.expectEmit(true, true, true, false, address(raila));
        emit IERC721.Transfer(address(777), address(0), 1);

        vm.prank(address(1337));
        raila.payLoan(1, 1076830984986877400);
    }

    function test_AliceFullyPaysOneDayAfterMinPeriod() public {
        // numbers are slightly bigger to account for 1 day of extra interest
        vm.warp(block.timestamp + 86400 * 91);
        vm.prank(address(777));
        usd.transfer(address(1337), 76830984986877400);
        vm.prank(address(1337));
        usd.approve(address(raila), 1076830984986877400);
        // alice usd => raila
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(1337), address(raila), 1076830984986877400);
        // payment announcement
        vm.expectEmit(true, false, false, true, address(raila));
        emit Raila.LoanRepayment(1, 1067598105382081556, 0);
        // total to creditor (original + most of interest)
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), address(777), 1064218200112977479);
        // fees to raila treasury (feeRate * interest)
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), address(1000), 3379905269104077);
        // excess back to usd sender
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), address(1337), 9232879604795844);
        // full payment destroys the loan nft
        vm.expectEmit(true, true, true, false, address(raila));
        emit IERC721.Transfer(address(777), address(0), 1);

        vm.prank(address(1337));
        raila.payLoan(1, 1076830984986877400);
    }

    function test_AliceOnlyPaysOriginalDebt() public {
        vm.prank(address(1337));
        usd.approve(address(raila), 1000000000000000000);
        // alice usd => raila
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(1337), address(raila), 1000000000000000000);
        // payment announcement. there's debt remaining
        vm.expectEmit(true, false, false, true, address(raila));
        emit Raila.LoanRepayment(1, 1000000000000000000, 66830984986877400);
        // total to creditor (original), no interest debt paid.
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), address(777), 1000000000000000000);
        // no fees to raila treasury
        // no excess back to usd sender
        // loan was not extinguished
        vm.prank(address(1337));
        raila.payLoan(1, 1000000000000000000);
        // loan was not extinguished, so ref must remain
        assertEq(raila.borrowerToRequestId(bytes20(address(69))), 1);
        // loan remains, but original debt has been paid
        (bytes20 debtor, uint40 createdAtBlock, Raila.RequestStatus status, address creditor, uint40 fundedAt,
        uint40 lastUpdatedAt, uint16 feeRate, UD60x18 interestRatePerSecond,
        uint256 originalDebt, uint256 totalDebt, uint256 defaultThreshold) = raila.requests(1);
        vm.assertEq(debtor, bytes20(address(69)));
        vm.assertEq(createdAtBlock, block.number);
        vm.assertEq(uint8(status), uint8(1));
        vm.assertEq(creditor, address(777));
        vm.assertEq(fundedAt, block.timestamp);
        // payment before the min interest period, so lastUpdatedAt is min period + fundedAt
        vm.assertEq(lastUpdatedAt, block.timestamp + 86400 * 90); 
        vm.assertEq(feeRate, 500);
        vm.assertEq(interestRatePerSecond.unwrap(), INTEREST_RATE_30_YEAR);
        vm.assertEq(originalDebt, 0); // fully paid
        vm.assertEq(totalDebt, 66830984986877400);
        vm.assertEq(defaultThreshold, 2 ether);
    }

    function test_AlicePaysOriginalDebtPartially() public {
        vm.prank(address(1337));
        usd.approve(address(raila), 0.01 ether);
        // alice usd => raila
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(1337), address(raila), 0.01 ether);
        // payment announcement. there's debt remaining
        vm.expectEmit(true, false, false, true, address(raila));
        emit Raila.LoanRepayment(1, 0.01 ether, 1056830984986877400);
        // total to creditor (original), no interest debt paid.
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), address(777), 0.01 ether);
        // no fees to raila treasury
        // no excess back to usd sender
        // loan was not extinguished
        vm.prank(address(1337));
        raila.payLoan(1, 0.01 ether);
        // loan was not extinguished, so ref must remain
        assertEq(raila.borrowerToRequestId(bytes20(address(69))), 1);
        // loan remains, only some original debt has been paid
        (bytes20 debtor, uint40 createdAtBlock, Raila.RequestStatus status, address creditor, uint40 fundedAt,
        uint40 lastUpdatedAt, uint16 feeRate, UD60x18 interestRatePerSecond,
        uint256 originalDebt, uint256 totalDebt, uint256 defaultThreshold) = raila.requests(1);
        vm.assertEq(debtor, bytes20(address(69)));
        vm.assertEq(createdAtBlock, block.number);
        vm.assertEq(uint8(status), uint8(1));
        vm.assertEq(creditor, address(777));
        vm.assertEq(fundedAt, block.timestamp);
        // payment before the min interest period, so lastUpdatedAt is min period + fundedAt
        vm.assertEq(lastUpdatedAt, block.timestamp + 86400 * 90); 
        vm.assertEq(feeRate, 500);
        vm.assertEq(interestRatePerSecond.unwrap(), INTEREST_RATE_30_YEAR);
        vm.assertEq(originalDebt, 0.99 ether); // fully paid
        vm.assertEq(totalDebt, 1056830984986877400);
        vm.assertEq(defaultThreshold, 2 ether);
    }

    function test_OriginalDebtDoesNotGrow() public {
        vm.warp(block.timestamp + 1000 days); // few years pass, but original debt is stuck.
        vm.prank(address(1337));
        usd.approve(address(raila), 0.01 ether);
        vm.prank(address(1337));
        raila.payLoan(1, 0.01 ether);
        (,,,,,,,,uint256 originalDebt,,) = raila.requests(1);
        vm.assertEq(originalDebt, 0.99 ether);
    }

    function test_AlicePaysOriginalAndSomeInterest() public {
        vm.prank(address(777));
        usd.transfer(address(1337), 0.01 ether);
        vm.prank(address(1337));
        usd.approve(address(raila), 1.01 ether);
        vm.prank(address(1337));
        // payment announcement
        vm.expectEmit(true, false, false, true, address(raila));
        emit Raila.LoanRepayment(1, 1.01 ether, 56830984986877400);
        // total to creditor (original + most of interest)
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), address(777), 1009500000000000000);
        // fees to raila treasury (feeRate * interest)
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), address(1000), 500000000000000);
        raila.payLoan(1, 1.01 ether);

        (,,,,,,,,uint256 originalDebt, uint256 totalDebt,) = raila.requests(1);
        vm.assertEq(originalDebt, 0 ether);
        vm.assertEq(totalDebt, 56830984986877400);
    }

    function test_PayingDebtInBatches() public {
        // realistic amortization of debt in a few batches separated by time
        vm.prank(address(1337));
        usd.approve(address(raila), 100 ether);
        // batch 1
        uint256 originTime = block.timestamp;
        vm.warp(block.timestamp + 100 days);
        vm.prank(address(777));
        usd.transfer(address(1337), 0.5 ether);
        vm.prank(address(1337));
        raila.payLoan(1, 0.5 ether);
        assertEq(raila.borrowerToRequestId(bytes20(address(69))), 1); // loan still alive
        (,,,,uint256 fundedAt1,uint256 lastUpdated1,,,uint256 originalDebt1,uint256 totalDebt1,) = raila.requests(1);
        vm.assertEq(fundedAt1, originTime);
        vm.assertEq(lastUpdated1, originTime + 100 days);
        vm.assertLt(fundedAt1, lastUpdated1); // invariant: while loan, funded < lastUpdated
        vm.assertEq(originalDebt1, 0.5 ether);
        vm.assertEq(totalDebt1, 574527059006372707);
        vm.assertLt(originalDebt1, totalDebt1); // invariant: while loan, ogd < totd
        // batch 2
        vm.warp(block.timestamp + 100 days);
        vm.prank(address(777));
        usd.transfer(address(1337), 0.5 ether);
        vm.prank(address(1337));
        raila.payLoan(1, 0.5 ether);
        assertEq(raila.borrowerToRequestId(bytes20(address(69))), 1); // loan still alive
        (,,,,uint256 fundedAt2,uint256 lastUpdated2,,,uint256 originalDebt2,uint256 totalDebt2,) = raila.requests(1);
        vm.assertEq(fundedAt2, originTime);
        vm.assertEq(lastUpdated2, originTime + 200 days);
        vm.assertEq(originalDebt2, 0);
        vm.assertEq(totalDebt2, 117344871033698420);
        // batch 3
        vm.warp(block.timestamp + 100 days);
        vm.prank(address(777));
        usd.transfer(address(1337), 0.5 ether);
        // lets make sure she gets the excess
        // alice usd => raila
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(1337), address(raila), 0.5 ether);
        // payment announcement
        vm.expectEmit(true, false, false, true, address(raila));
        emit Raila.LoanRepayment(1, 126090239161322057, 0);
        // total to creditor
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), address(777), 119785727203255955);
        // fees to raila treasury (feeRate * interest)
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), address(1000), 6304511958066102);
        // excess back to usd sender
        vm.expectEmit(true, true, false, true, address(usd));
        emit IERC20.Transfer(address(raila), address(1337), 373909760838677943);
        // full payment destroys the loan nft
        vm.expectEmit(true, true, true, false, address(raila));
        emit IERC721.Transfer(address(777), address(0), 1);

        vm.prank(address(1337));
        raila.payLoan(1, 0.5 ether);
        assertEq(raila.borrowerToRequestId(bytes20(address(69))), 0); // loan now dead
        (,,,,,,,,uint256 originalDebt3,uint256 totalDebt3,) = raila.requests(1);
        vm.assertEq(originalDebt3, 0);
        vm.assertEq(totalDebt3, 0);
        // treasury should've obtained some money, ~6 mETH
        vm.assertLe(0.006 ether, usd.balanceOf(address(1000)));
    }

    function test_ThirdPartyCanPayLoan() public {
        vm.prank(address(777));
        usd.transfer(address(333), 2 ether);
        vm.prank(address(333));
        usd.approve(address(raila), 2 ether);
        vm.prank(address(333));
        raila.payLoan(1, 2 ether);
        assertEq(raila.borrowerToRequestId(bytes20(address(69))), 0); // loan now dead
    }

    function testFail_NoPayWithoutApproval() public {
        vm.prank(address(777));
        usd.transfer(address(333), 2 ether);
        vm.prank(address(333));
        raila.payLoan(1, 2 ether);
    }

    function testFail_NoPayLoanDoesNotExist() public {
        vm.prank(address(777));
        usd.transfer(address(333), 2 ether);
        vm.prank(address(333));
        usd.approve(address(raila), 2 ether);
        vm.prank(address(333));
        raila.payLoan(2, 2 ether);
    }

    function testFail_NoPayLoanCompleted() public {
        vm.prank(address(777));
        usd.transfer(address(333), 2 ether);
        vm.prank(address(333));
        usd.approve(address(raila), 2 ether);
        vm.prank(address(333));
        raila.payLoan(1, 2 ether);
        // loan is now paid, so this payment must fail
        vm.prank(address(333));
        raila.payLoan(1, 0.1 ether);
    }

    function test_CanPayWithZero() public {
        vm.prank(address(333));
        raila.payLoan(1, 0);
    }

    function test_PayingWithZeroCanUpdateValues() public {
        // paying 0 at time 0 is a noop
        vm.prank(address(333));
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
        vm.prank(address(333));
        raila.payLoan(1, 0);
        (,,,,uint256 fundedAt2,uint256 lastUpdated2,,,uint256 originalDebt2,uint256 totalDebt2,) = raila.requests(1);
        vm.assertEq(fundedAt2, originTime);
        vm.assertEq(lastUpdated2, originTime + 86400 * 90 + 1000 days);
        vm.assertEq(originalDebt2, 1 ether);
        vm.assertEq(totalDebt2, 2189118068668009296); // has increased.
    }
}

// misc checks:
// 2 loans with equal ogd and distinct interestRates grow at different speeds
// changing the contract's feeRate doesnt modify the (already filed) request feeRate