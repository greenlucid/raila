// SPDX-License-Identifier: MIT

pragma solidity ^0.8;

/// @title IProofOfHumanity
interface IProofOfHumanity {
    function humanityOf(address owner) external returns (bytes20);
    function boundTo(bytes20 _humanityId) external view returns (address);
    //function isHuman(bytes20 owner) external returns (bool);
}
