//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {IProofOfHumanity} from "../src/IProofOfHumanity.sol";
import {Raila} from "../src/Raila.sol";
import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";

contract Deploy is Script {
    function run() external {
        // Start broadcasting a transaction with the provided private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the contract
        Raila raila = new Raila(
            address(1000),
            86400 * 90,
            ERC20(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d),
            IProofOfHumanity(0xa4AC94C4fa65Bb352eFa30e3408e64F72aC857bc),
            500
        );
        vm.stopBroadcast();

        console.log("Raila deployed at:", address(raila));
    }
}
