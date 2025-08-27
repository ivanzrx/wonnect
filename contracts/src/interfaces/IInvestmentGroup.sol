// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IInvestmentGroup
 * @dev Interface for Investment Group contracts
 */
interface IInvestmentGroup {
    enum GroupState {
        Fundraising,
        Active,
        Exited,
        Liquidated
    }
    
    struct SAFETerms {
        uint256 valuationCap;
        uint256 discountRate;
        bool hasMostFavoredNation;
        bool hasProRataRights;
    }
    
    function commitInvestment(uint256 amount) external;
    
    function executeInvestment() external;
    
    function processExit(uint256 exitAmount) external;
    
    function emergencyWithdraw(string calldata reason) external;
    
    function leadInvestor() external view returns (address);
    
    function currentState() external view returns (GroupState);
    
    function totalCommitted() external view returns (uint256);
    
    function getGroupInfo() external view returns (
        string memory,
        string memory,
        uint256,
        uint256,
        uint256,
        uint256,
        GroupState,
        uint256,
        uint256
    );
}