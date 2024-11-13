// SPDX-License-Identifier: MIT

pragma solidity ^0.8;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IProofOfHumanity} from "../src/IProofOfHumanity.sol";
import {Raila} from "../src/Raila.sol";
import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";
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
        raila = new Raila(address(1000), 86400 * 90, usd, poh, 500);
        assertEq(raila.RAILA_TREASURY(), address(1000));
        assertEq(raila.MINIMUM_INTEREST_PERIOD(), 86400 * 90);
        assertEq(address(raila.USD()), address(usd));
        assertEq(address(raila.PROOF_OF_HUMANITY()), address(poh));
        assertEq(raila.feeRate(), 500);
    }
    // todo test some core functionality here too, like changing fee base rate, governor etc
}

contract CreateRequest is Test {
    IProofOfHumanity poh;
    ERC20 usd;
    Raila raila;

    event RequestCreation(
        bytes20 indexed debtor, uint256 indexed requestId, string requestMetadata
    );

    uint256 constant INTEREST_RATE_30_YEAR = 1000000008319516200; 

    function setUp() public {
        poh = new MockPoH();
        usd = new PolloCoin(1e18);
        raila = new Raila(address(1000), 86400 * 90, usd, poh, 500);
    }

    function test_RequestLogs() public {
        vm.prank(address(1337));
        vm.expectEmit(true, true, false, true);
        emit RequestCreation(bytes20(address(69)), 1, "");
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

    event RequestCanceled(uint256 indexed requestId);

    uint256 constant INTEREST_RATE_30_YEAR = 1000000008319516200;

    function setUp() public {
        poh = new MockPoH();
        vm.prank(address(777));
        usd = new PolloCoin(100 ether);
        raila = new Raila(address(1000), 86400 * 90, usd, poh, 500);
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
        emit RequestCanceled(1);
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