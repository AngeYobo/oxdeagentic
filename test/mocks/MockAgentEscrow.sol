// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract MockAgentEscrow {
    mapping(address => uint64) public firstSeen;

    function setFirstSeen(address payer, uint64 timestamp) external {
        firstSeen[payer] = timestamp;
    }

    function initializeFirstSeen(address payer) external {
        if (firstSeen[payer] == 0) {
            firstSeen[payer] = uint64(block.timestamp);
        }
    }
}
