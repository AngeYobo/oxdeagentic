// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract MockStakeManager {
    bool public wasLockCalled;
    bool public wasUnlockCalled;
    bool public wasSlashCalled;

    mapping(bytes32 => bool) public lockedIntents;

    function lockStake(address, address, uint256, bytes32 intentId) external {
        wasLockCalled = true;
        lockedIntents[intentId] = true;
    }

    function unlockStake(bytes32 intentId) external {
        wasUnlockCalled = true;
        lockedIntents[intentId] = false;
    }

    function slash(
        bytes32,
        /*intentId*/
        uint256 /*amount*/
    )
        external
    {
        wasSlashCalled = true;
    }

    function reset() external {
        wasLockCalled = false;
        wasUnlockCalled = false;
        wasSlashCalled = false;
    }
}
