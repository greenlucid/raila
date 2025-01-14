//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {IProofOfHumanity} from "../src/IProofOfHumanity.sol";
import {Raila} from "../src/Raila.sol";
import {UD60x18, powu} from "@prb-math/src/UD60x18.sol";
import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";

UD60x18 constant INTEREST_RATE_MAX = UD60x18.wrap(1000000831951620000);

contract Deploy is Script {
    function run() external {
        // Start broadcasting a transaction with the provided private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);


        // Deploy the contract
        Raila raila = new Raila(
            0x4ED2addA46A7e24d06CE1BaACC6a4b69c1FAB404,
            0x4ED2addA46A7e24d06CE1BaACC6a4b69c1FAB404,
            86400 * 90,
            INTEREST_RATE_MAX,
            ERC20(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d),
            IProofOfHumanity(0xa4AC94C4fa65Bb352eFa30e3408e64F72aC857bc),
            500
        );
        vm.stopBroadcast();

        console.log("Raila deployed at:", address(raila));
    }
}
