// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../InvestmentGroup.sol";

/**
 * @title IWonConnectFactory
 * @dev Interface for WonConnect Factory contract
 */
interface IWonConnectFactory {
    function createInvestmentGroup(
        string calldata startupName,
        string calldata startupDescription,
        uint256 targetAmount,
        uint256 minimumInvestment,
        uint256 maximumInvestment,
        uint256 investmentDeadline,
        uint256 hurdleRate,
        uint256 carryRate,
        InvestmentGroup.SAFETerms calldata safeTerms
    ) external returns (address);
    
    function collectBrokerageFee(uint256 amount) external;
    
    function verifiedLeadInvestors(address) external view returns (bool);
    
    function isInvestmentGroup(address) external view returns (bool);
    
    function treasury() external view returns (address);
}