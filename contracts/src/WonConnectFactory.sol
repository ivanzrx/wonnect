// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./InvestmentGroup.sol";
import "./interfaces/IKRW.sol";

/**
 * @title WonConnectFactory
 * @dev Main factory contract for creating and managing investment syndicates
 * @notice Creates investment groups, manages lead investors, and collects platform fees
 */
contract WonConnectFactory is Ownable, ReentrancyGuard, Pausable {
    /// @dev KRW stablecoin contract
    IKRW public immutable krwToken;
    
    /// @dev Platform treasury address
    address public treasury;
    
    /// @dev Platform fee rates (basis points)
    uint256 public brokerageFeeRate = 200;    // 2% brokerage fee
    uint256 public operatingFeeAmount = 5_000_000 * 1e18; // 5M KRW per deal
    uint256 public platformCarryRate = 2000;   // 20% of GP carry
    
    /// @dev Subscription tiers
    struct SubscriptionTier {
        uint256 monthlyFee;     // Monthly fee in KRW
        bool isActive;          // Whether tier is active
        string name;            // Tier name
        string[] benefits;      // List of benefits
    }
    
    mapping(string => SubscriptionTier) public subscriptionTiers;
    
    /// @dev User subscriptions
    struct UserSubscription {
        string tierName;
        uint256 lastPayment;
        uint256 expiryDate;
        bool isActive;
    }
    
    mapping(address => UserSubscription) public userSubscriptions;
    
    /// @dev Lead investor management
    mapping(address => bool) public verifiedLeadInvestors;
    mapping(address => uint256) public leadInvestorFees; // Fees earned by each GP
    mapping(address => uint256) public leadInvestorDeals; // Number of deals created
    
    /// @dev Investment group tracking
    address[] public investmentGroups;
    mapping(address => bool) public isInvestmentGroup;
    mapping(address => address[]) public leadInvestorGroups; // GP => groups created
    
    /// @dev Platform statistics
    uint256 public totalVolumeProcessed;
    uint256 public totalFeesCollected;
    uint256 public totalGroupsCreated;
    uint256 public totalActiveSubscribers;
    
    /// @dev Membership and access control
    mapping(address => bool) public premiumMembers;
    mapping(address => uint256) public memberJoinDate;
    
    /// Events
    event InvestmentGroupCreated(
        address indexed group,
        address indexed leadInvestor,
        string startupName,
        uint256 targetAmount,
        uint256 deadline
    );
    
    event LeadInvestorVerified(
        address indexed leadInvestor,
        string name,
        string credentials
    );
    
    event LeadInvestorRemoved(address indexed leadInvestor);
    
    event SubscriptionPurchased(
        address indexed user,
        string tierName,
        uint256 amount,
        uint256 expiryDate
    );
    
    event BrokerageFeeCollected(
        address indexed group,
        address indexed leadInvestor,
        uint256 amount
    );
    
    event OperatingFeeCollected(
        address indexed group,
        address indexed leadInvestor,
        uint256 amount
    );
    
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    
    event FeeRatesUpdated(
        uint256 newBrokerageFee,
        uint256 newOperatingFee,
        uint256 newPlatformCarry
    );
    
    /// Errors
    error NotVerifiedLeadInvestor();
    error InvalidParameters();
    error InsufficientSubscription();
    error PaymentFailed();
    error UnauthorizedAccess();
    error InvalidGroup();
    error SubscriptionExpired();
    
    /// Modifiers
    modifier onlyVerifiedGP() {
        if (!verifiedLeadInvestors[msg.sender]) revert NotVerifiedLeadInvestor();
        _;
    }
    
    modifier validSubscription() {
        UserSubscription memory sub = userSubscriptions[msg.sender];
        if (!sub.isActive || sub.expiryDate < block.timestamp) {
            revert SubscriptionExpired();
        }
        _;
    }
    
    modifier onlyInvestmentGroup() {
        if (!isInvestmentGroup[msg.sender]) revert InvalidGroup();
        _;
    }
    
    /**
     * @dev Constructor
     * @param _krwToken KRW stablecoin contract address
     * @param _treasury Initial treasury address
     */
    constructor(address _krwToken, address _treasury) Ownable(msg.sender) {
        krwToken = IKRW(_krwToken);
        treasury = _treasury;
        
        // Initialize subscription tiers
        _initializeSubscriptionTiers();
    }
    
    /**
     * @dev Initialize subscription tiers
     */
    function _initializeSubscriptionTiers() internal {
        // Basic Tier
        subscriptionTiers["basic"] = SubscriptionTier({
            monthlyFee: 30_000 * 1e18, // 30K KRW
            isActive: true,
            name: "Basic",
            benefits: new string[](0)
        });
        
        // Professional Tier  
        subscriptionTiers["professional"] = SubscriptionTier({
            monthlyFee: 80_000 * 1e18, // 80K KRW
            isActive: true,
            name: "Professional", 
            benefits: new string[](0)
        });
    }
    
    /**
     * @dev Create new investment group
     * @param startupName Name of target startup
     * @param startupDescription Description of startup
     * @param targetAmount Target investment amount
     * @param minimumInvestment Minimum investment per LP
     * @param maximumInvestment Maximum investment per LP
     * @param investmentDeadline Investment deadline
     * @param hurdleRate Hurdle rate for profit distribution
     * @param carryRate Carry rate for GP
     * @param safeTerms SAFE contract terms
     */
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
    ) 
        external 
        onlyVerifiedGP
        validSubscription
        whenNotPaused
        nonReentrant
        returns (address)
    {
        if (targetAmount == 0 || investmentDeadline <= block.timestamp) {
            revert InvalidParameters();
        }
        
        // Collect operating fee from GP
        krwToken.transferFrom(msg.sender, treasury, operatingFeeAmount);
        leadInvestorFees[msg.sender] += operatingFeeAmount;
        totalFeesCollected += operatingFeeAmount;
        
        // Create new investment group
        InvestmentGroup newGroup = new InvestmentGroup(
            address(krwToken),
            address(this),
            msg.sender,
            startupName,
            startupDescription,
            targetAmount,
            minimumInvestment,
            maximumInvestment,
            investmentDeadline,
            hurdleRate,
            carryRate,
            safeTerms
        );
        
        // Register group
        address groupAddress = address(newGroup);
        investmentGroups.push(groupAddress);
        isInvestmentGroup[groupAddress] = true;
        leadInvestorGroups[msg.sender].push(groupAddress);
        leadInvestorDeals[msg.sender]++;
        totalGroupsCreated++;
        
        emit InvestmentGroupCreated(
            groupAddress,
            msg.sender,
            startupName,
            targetAmount,
            investmentDeadline
        );
        
        emit OperatingFeeCollected(groupAddress, msg.sender, operatingFeeAmount);
        
        return groupAddress;
    }
    
    /**
     * @dev Collect brokerage fee from investment group
     * @param amount Amount to collect fee on
     */
    function collectBrokerageFee(uint256 amount) 
        external 
        onlyInvestmentGroup
        whenNotPaused
        nonReentrant
    {
        uint256 fee = (amount * brokerageFeeRate) / 10000;
        
        // Get group details to identify GP
        InvestmentGroup group = InvestmentGroup(msg.sender);
        address leadInvestor = group.leadInvestor();
        
        krwToken.transferFrom(msg.sender, treasury, fee);
        leadInvestorFees[leadInvestor] += fee;
        totalFeesCollected += fee;
        totalVolumeProcessed += amount;
        
        emit BrokerageFeeCollected(msg.sender, leadInvestor, fee);
    }
    
    /**
     * @dev Verify lead investor
     * @param leadInvestor Address to verify
     * @param name GP name
     * @param credentials GP credentials
     */
    function verifyLeadInvestor(
        address leadInvestor,
        string calldata name,
        string calldata credentials
    ) 
        external 
        onlyOwner 
    {
        verifiedLeadInvestors[leadInvestor] = true;
        emit LeadInvestorVerified(leadInvestor, name, credentials);
    }
    
    /**
     * @dev Remove lead investor verification
     * @param leadInvestor Address to remove
     */
    function removeLeadInvestor(address leadInvestor) external onlyOwner {
        verifiedLeadInvestors[leadInvestor] = false;
        emit LeadInvestorRemoved(leadInvestor);
    }
    
    /**
     * @dev Purchase subscription
     * @param tierName Subscription tier name
     * @param months Number of months to purchase
     */
    function purchaseSubscription(string calldata tierName, uint256 months) 
        external 
        whenNotPaused
        nonReentrant
    {
        SubscriptionTier memory tier = subscriptionTiers[tierName];
        if (!tier.isActive || months == 0) revert InvalidParameters();
        
        uint256 totalCost = tier.monthlyFee * months;
        
        // Transfer payment
        krwToken.transferFrom(msg.sender, treasury, totalCost);
        
        // Update subscription
        UserSubscription storage sub = userSubscriptions[msg.sender];
        
        uint256 newExpiryDate;
        if (sub.isActive && sub.expiryDate > block.timestamp) {
            // Extend existing subscription
            newExpiryDate = sub.expiryDate + (months * 30 days);
        } else {
            // New subscription
            newExpiryDate = block.timestamp + (months * 30 days);
            if (!sub.isActive) {
                totalActiveSubscribers++;
            }
        }
        
        sub.tierName = tierName;
        sub.lastPayment = block.timestamp;
        sub.expiryDate = newExpiryDate;
        sub.isActive = true;
        
        // Update membership status
        if (!premiumMembers[msg.sender]) {
            premiumMembers[msg.sender] = true;
            memberJoinDate[msg.sender] = block.timestamp;
        }
        
        totalFeesCollected += totalCost;
        
        emit SubscriptionPurchased(msg.sender, tierName, totalCost, newExpiryDate);
    }
    
    /**
     * @dev Update platform fee rates
     * @param newBrokerageFee New brokerage fee rate (basis points)
     * @param newOperatingFee New operating fee amount
     * @param newPlatformCarry New platform carry rate (basis points)
     */
    function updateFeeRates(
        uint256 newBrokerageFee,
        uint256 newOperatingFee,
        uint256 newPlatformCarry
    ) external onlyOwner {
        require(newBrokerageFee <= 500, "Brokerage fee too high"); // Max 5%
        require(newPlatformCarry <= 5000, "Platform carry too high"); // Max 50%
        
        brokerageFeeRate = newBrokerageFee;
        operatingFeeAmount = newOperatingFee;
        platformCarryRate = newPlatformCarry;
        
        emit FeeRatesUpdated(newBrokerageFee, newOperatingFee, newPlatformCarry);
    }
    
    /**
     * @dev Update treasury address
     * @param newTreasury New treasury address
     */
    function updateTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury");
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }
    
    /**
     * @dev Get investment groups created by lead investor
     * @param leadInvestor Lead investor address
     */
    function getLeadInvestorGroups(address leadInvestor) 
        external 
        view 
        returns (address[] memory) 
    {
        return leadInvestorGroups[leadInvestor];
    }
    
    /**
     * @dev Get all investment groups
     */
    function getAllInvestmentGroups() external view returns (address[] memory) {
        return investmentGroups;
    }
    
    /**
     * @dev Get user subscription info
     * @param user User address
     */
    function getUserSubscription(address user) 
        external 
        view 
        returns (UserSubscription memory) 
    {
        return userSubscriptions[user];
    }
    
    /**
     * @dev Get subscription tier info
     * @param tierName Tier name
     */
    function getSubscriptionTier(string calldata tierName) 
        external 
        view 
        returns (SubscriptionTier memory) 
    {
        return subscriptionTiers[tierName];
    }
    
    /**
     * @dev Get platform statistics
     */
    function getPlatformStats() external view returns (
        uint256 totalVolume,
        uint256 totalFees,
        uint256 totalGroups,
        uint256 activeSubscribers,
        uint256 verifiedGPs
    ) {
        // Count verified GPs (this is expensive, consider caching)
        uint256 gpCount = 0;
        // In production, you'd want to maintain this as a state variable
        
        return (
            totalVolumeProcessed,
            totalFeesCollected,
            totalGroupsCreated,
            totalActiveSubscribers,
            gpCount
        );
    }
    
    /**
     * @dev Check if user has valid subscription for tier
     * @param user User address
     * @param requiredTier Required tier name
     */
    function hasValidSubscription(address user, string calldata requiredTier) 
        external 
        view 
        returns (bool) 
    {
        UserSubscription memory sub = userSubscriptions[user];
        if (!sub.isActive || sub.expiryDate < block.timestamp) {
            return false;
        }
        
        // For now, just check if they have any active subscription
        // In production, implement tier hierarchy
        return true;
    }
    
    /**
     * @dev Pause contract
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Emergency withdraw function
     * @param token Token address (0x0 for ETH)
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            payable(treasury).transfer(amount);
        } else {
            IKRW(token).transfer(treasury, amount);
        }
    }
    
    /**
     * @dev Get contract version
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}