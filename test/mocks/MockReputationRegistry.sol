// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract MockReputationRegistry {
    bool public wasRecordCalled;
    
    address public lastPayer;
    address public lastProvider;
    uint16 public lastGain;
    
    mapping(address => uint16) public scores;
    
    function recordSuccess(address payer, address provider, uint16 gain) external {
        wasRecordCalled = true;
        lastPayer = payer;
        lastProvider = provider;
        lastGain = gain;
    }
    
    function getScore(address provider) external view returns (uint16) {
        return scores[provider];
    }
    
    function setScore(address provider, uint16 score) external {
        scores[provider] = score;
    }
    
    function reset() external {
        wasRecordCalled = false;
    }
}
