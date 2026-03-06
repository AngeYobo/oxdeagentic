// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract MockInsurancePool {
    uint256 public notifiedAmount;
    bool private wasAuthorizeCalled_;

    mapping(bytes32 => bytes32) public claimIdByIntent;

    function notifyDepositFromStake(address, uint256 amount) external {
        notifiedAmount += amount;
    }

    function authorizeClaim(bytes32 intentId, address, address, address, uint128, uint128)
        external
        returns (bytes32 claimId)
    {
        wasAuthorizeCalled_ = true;

        claimId = keccak256(abi.encodePacked(block.chainid, address(this), intentId));
        claimIdByIntent[intentId] = claimId;
    }

    function wasAuthorizeCalled() external view returns (bool) {
        return wasAuthorizeCalled_;
    }

    function reset() external {
        notifiedAmount = 0;
        wasAuthorizeCalled_ = false;
    }
}
