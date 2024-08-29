// SPDX-License-Identifier: MIT

pragma solidity ^0.8;

/// @title IProofOfHumanity
interface IProofOfHumanity {
    function addressToHumanity(address owner) external returns (bytes20);
    function isHuman(bytes20 owner) external returns (bool);
}
