// SPDX-License-Identifier: MIT

pragma solidity ^0.8;

import "forge-std/Test.sol";
import {IProofOfHumanity} from "../src/IProofOfHumanity.sol";
import {Raila} from "../src/Raila.sol";
import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";
import {UD60x18, powu} from "@prb-math/src/UD60x18.sol";

contract MockPoH is IProofOfHumanity {
    function humanityOf(address owner) public pure returns (bytes20) {
        if (owner == address(1337)) return bytes20(address(69));
        else return bytes20(address(0));
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
        poh = new MockPoH();
        usd = new PolloCoin(1e18);
    }

    function test_ConstructorSetsVariables() public {
        raila = new Raila(address(1000), 86400, usd, poh, 500);
        assertEq(raila.RAILA_TREASURY(), address(1000));
        assertEq(raila.MINIMUM_INTEREST_PERIOD(), 86400);
        assertEq(address(raila.USD()), address(usd));
        assertEq(address(raila.PROOF_OF_HUMANITY()), address(poh));
        assertEq(raila.feeRate(), 500);
    }
}

contract CreateRequest is Test {
    IProofOfHumanity poh;
    ERC20 usd;
    Raila raila;

    function setUp() public {
        poh = new MockPoH();
        usd = new PolloCoin(1e18);
        raila = new Raila(address(1000), 86400, usd, poh, 500);
    }

    function testFail_RequesterMustBeHuman() public {
        vm.prank(address(1336));
        raila.createRequest(100, UD60x18.wrap(100), 100, "");
    }

    function test_RequesterMustBeHuman() public {
        vm.prank(address(1337));
        raila.createRequest(100, UD60x18.wrap(100), 100, "");
    }

    function testFail_MaxOneRequestPerHuman() public {
        vm.prank(address(1337));
        raila.createRequest(100, UD60x18.wrap(100), 100, "");
        raila.createRequest(100, UD60x18.wrap(100), 100, "");
    }
}