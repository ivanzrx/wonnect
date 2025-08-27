// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IKRW.sol";
import "./LPShareNFT.sol";

/**
 * @title InvestmentGroup
 * @dev Individual syndicate contract for startup investments with SAFE structure
 * @notice Manages investment commitments, distributions, and SAFE contract integration
 */
contract InvestmentGroup is Ownable, ReentrancyGuard, Pausable {
    /// @dev KRW stablecoin contract
    IKRW public immutable krwToken;
    
    /// @dev LP Share NFT contract
    LPShareNFT public immutable lpShareNFT;
    
    /// @dev WonConnect Factory contract
    address public immutable factory;
    
    /// @dev Lead investor (GP) address
    address public immutable leadInvestor;
    
    /// @dev Target startup company information
    string public startupName;
    string public startupDescription;
    
    /// @dev Investment terms
    uint256 public targetAmount;        // Target raise amount
    uint256 public minimumInvestment;   // Minimum investment per LP
    uint256 public maximumInvestment;   // Maximum investment per LP
    uint256 public investmentDeadline;  // Deadline for investments
    uint256 public hurdleRate;          // Hurdle rate (basis points, 800 = 8%)
    uint256 public carryRate;           // Carry interest rate (basis points, 2000 = 20%)
    
    /// @dev Investment state
    enum GroupState {
        Fundraising,    // Accepting investments
        Active,         // Investment executed, waiting for exit
        Exited,         // Exit completed, profits distributed
        Liquidated      // Liquidation completed
    }
    
    GroupState public currentState;
    
    /// @dev Financial tracking
    uint256 public totalCommitted;      // Total committed by LPs
    uint256 public totalInvested;       // Actual amount invested in startup
    uint256 public totalReturned;       // Total amount returned from exit
    uint256 public platformFees;        // Platform fees collected
    uint256 public gpCarry;             // GP carry earned
    
    /// @dev SAFE contract terms
    struct SAFETerms {
        uint256 valuationCap;           // Valuation cap for SAFE
        uint256 discountRate;           // Discount rate (basis points)
        bool hasMostFavoredNation;      // MFN clause
        bool hasProRataRights;          // Pro rata participation rights
    }
    
    SAFETerms public safeTerms;
    
    /// @dev Investor tracking
    mapping(address => uint256) public commitments;
    mapping(address => uint256) public lpTokenIds;
    mapping(address => bool) public hasCommitted;
    address[] public investors;
    
    /// @dev Fee distribution
    uint256 public constant PLATFORM_FEE_RATE = 200; // 2% platform fee
    uint256 public constant BASIS_POINTS = 10000;
    
    /// Events
    event InvestmentCommitted(
        address indexed investor,
        uint256 amount,
        uint256 tokenId
    );
    
    event InvestmentExecuted(
        uint256 totalAmount,
        string startupDetails
    );
    
    event ProfitDistributed(
        uint256 totalProfit,
        uint256 lpShare,
        uint256 gpCarry,
        uint256 platformFee
    );
    
    event GroupStateChanged(
        GroupState oldState,
        GroupState newState
    );
    
    event ExitCompleted(
        uint256 totalReturns,
        uint256 totalProfit,
        uint256 returnMultiple
    );
    
    event EmergencyWithdraw(
        address indexed investor,
        uint256 amount,
        string reason
    );
    
    /// Errors
    error InvalidState();
    error InsufficientAmount();
    error ExceedsMaximum();
    error DeadlineExceeded();
    error NotAuthorized();
    error InvalidParameters();
    error AlreadyCommitted();
    error InsufficientFunds();
    
    /// Modifiers
    modifier onlyFactory() {
        if (msg.sender != factory) revert NotAuthorized();
        _;
    }
    
    modifier onlyLeadInvestor() {
        if (msg.sender != leadInvestor) revert NotAuthorized();
        _;
    }
    
    modifier inState(GroupState _state) {
        if (currentState != _state) revert InvalidState();
        _;
    }
    
    modifier beforeDeadline() {
        if (block.timestamp > investmentDeadline) revert DeadlineExceeded();
        _;
    }
    
    /**
     * @dev Constructor
     * @param _krwToken KRW stablecoin address
     * @param _factory Factory contract address
     * @param _leadInvestor Lead investor address
     * @param _startupName Startup company name
     * @param _targetAmount Target investment amount
     * @param _investmentDeadline Investment deadline
     * @param _safeTerms SAFE contract terms
     */
    constructor(
        address _krwToken,
        address _factory,
        address _leadInvestor,
        string memory _startupName,
        string memory _startupDescription,
        uint256 _targetAmount,
        uint256 _minimumInvestment,
        uint256 _maximumInvestment,
        uint256 _investmentDeadline,
        uint256 _hurdleRate,
        uint256 _carryRate,
        SAFETerms memory _safeTerms
    ) Ownable(msg.sender) {
        if (_targetAmount == 0 || _minimumInvestment == 0) revert InvalidParameters();
        if (_investmentDeadline <= block.timestamp) revert InvalidParameters();
        if (_hurdleRate > 2000 || _carryRate > 5000) revert InvalidParameters(); // Max 20% hurdle, 50% carry
        
        krwToken = IKRW(_krwToken);
        factory = _factory;
        leadInvestor = _leadInvestor;
        startupName = _startupName;
        startupDescription = _startupDescription;
        targetAmount = _targetAmount;
        minimumInvestment = _minimumInvestment;
        maximumInvestment = _maximumInvestment;
        investmentDeadline = _investmentDeadline;
        hurdleRate = _hurdleRate;
        carryRate = _carryRate;
        safeTerms = _safeTerms;
        
        currentState = GroupState.Fundraising;
        
        // Create LP Share NFT contract
        string memory nftName = string(abi.encodePacked("WonConnect LP: ", _startupName));
        string memory nftSymbol = string(abi.encodePacked("WC-", _getSymbolFromName(_startupName)));
        
        lpShareNFT = new LPShareNFT(
            _krwToken,
            address(this),
            _factory, // Treasury is factory for now
            nftName,
            nftSymbol
        );
    }
    
    /**
     * @dev Commit investment to the group
     * @param amount Amount to invest in KRW
     */
    function commitInvestment(uint256 amount) 
        external 
        inState(GroupState.Fundraising)
        beforeDeadline
        whenNotPaused
        nonReentrant
    {
        if (amount < minimumInvestment) revert InsufficientAmount();
        if (amount > maximumInvestment) revert ExceedsMaximum();
        if (hasCommitted[msg.sender]) revert AlreadyCommitted();
        if (totalCommitted + amount > targetAmount) {
            amount = targetAmount - totalCommitted; // Cap at target
        }
        
        // Transfer KRW from investor
        krwToken.transferFrom(msg.sender, address(this), amount);
        
        // Record commitment
        commitments[msg.sender] = amount;
        hasCommitted[msg.sender] = true;
        totalCommitted += amount;
        investors.push(msg.sender);
        
        // Calculate shares (1 share per 1 KRW for simplicity)
        uint256 sharesOwned = amount;
        
        // Mint LP NFT
        uint256 tokenId = lpShareNFT.mintShare(msg.sender, amount, sharesOwned);
        lpTokenIds[msg.sender] = tokenId;
        
        emit InvestmentCommitted(msg.sender, amount, tokenId);
        
        // Auto-execute if target reached
        if (totalCommitted >= targetAmount) {
            _executeInvestment();
        }
    }
    
    /**
     * @dev Execute investment (deploy capital to startup)
     * @dev Can be called by lead investor after deadline even if target not reached
     */
    function executeInvestment() 
        external 
        onlyLeadInvestor
        inState(GroupState.Fundraising)
        whenNotPaused
    {
        if (block.timestamp <= investmentDeadline && totalCommitted < targetAmount) {
            revert InvalidState();
        }
        _executeInvestment();
    }
    
    /**
     * @dev Internal function to execute investment
     */
    function _executeInvestment() internal {
        if (totalCommitted == 0) revert InsufficientFunds();
        
        // Calculate platform fee
        uint256 platformFee = (totalCommitted * PLATFORM_FEE_RATE) / BASIS_POINTS;
        platformFees = platformFee;
        
        // Net investment amount after fees
        totalInvested = totalCommitted - platformFee;
        
        // Transfer platform fee to factory
        krwToken.transfer(factory, platformFee);
        
        // Change state
        GroupState oldState = currentState;
        currentState = GroupState.Active;
        
        emit GroupStateChanged(oldState, currentState);
        emit InvestmentExecuted(totalInvested, startupDescription);
    }
    
    /**
     * @dev Process exit returns (called when startup exits)
     * @param exitAmount Total amount returned from exit
     */
    function processExit(uint256 exitAmount) 
        external 
        onlyLeadInvestor
        inState(GroupState.Active)
        whenNotPaused
        nonReentrant
    {
        if (exitAmount == 0) revert InvalidParameters();
        
        // Transfer exit proceeds to contract
        krwToken.transferFrom(msg.sender, address(this), exitAmount);
        totalReturned = exitAmount;
        
        // Calculate profit distribution
        _distributeProfits(exitAmount);
        
        // Update state
        GroupState oldState = currentState;
        currentState = GroupState.Exited;
        
        emit GroupStateChanged(oldState, currentState);
        emit ExitCompleted(exitAmount, exitAmount - totalInvested, (exitAmount * BASIS_POINTS) / totalInvested);
    }
    
    /**
     * @dev Internal profit distribution logic (waterfall)
     * @param totalAmount Total amount to distribute
     */
    function _distributeProfits(uint256 totalAmount) internal {
        uint256 remainingAmount = totalAmount;
        
        // Step 1: Return of principal to LPs
        uint256 principalReturn = totalInvested > remainingAmount ? remainingAmount : totalInvested;
        remainingAmount -= principalReturn;
        
        if (remainingAmount > 0) {
            // Step 2: Hurdle rate to LPs
            uint256 hurdleAmount = (totalInvested * hurdleRate * 
                                  (block.timestamp - investmentDeadline)) / (BASIS_POINTS * 365 days);
            hurdleAmount = hurdleAmount > remainingAmount ? remainingAmount : hurdleAmount;
            remainingAmount -= hurdleAmount;
            
            // Step 3: Carry split between GP and platform
            if (remainingAmount > 0) {
                uint256 totalCarry = (remainingAmount * carryRate) / BASIS_POINTS;
                gpCarry = (totalCarry * 8000) / BASIS_POINTS; // 80% to GP
                uint256 platformCarry = totalCarry - gpCarry;  // 20% to platform
                
                // Transfer GP carry
                krwToken.transfer(leadInvestor, gpCarry);
                
                // Transfer platform carry
                krwToken.transfer(factory, platformCarry);
                
                // Remaining to LPs
                uint256 lpProfit = remainingAmount - totalCarry;
                
                // Distribute profits to LP NFT holders
                if (lpProfit > 0) {
                    krwToken.transfer(address(lpShareNFT), lpProfit);
                    lpShareNFT.distributeProfits(lpProfit);
                }
                
                emit ProfitDistributed(remainingAmount, lpProfit, gpCarry, platformCarry);
            }
        }
        
        // Return principal through NFT contract
        if (principalReturn > 0) {
            krwToken.transfer(address(lpShareNFT), principalReturn);
            lpShareNFT.distributeProfits(principalReturn);
        }
    }
    
    /**
     * @dev Emergency withdrawal for LPs (before execution)
     * @param reason Reason for emergency withdrawal
     */
    function emergencyWithdraw(string calldata reason) 
        external 
        inState(GroupState.Fundraising)
        whenNotPaused
        nonReentrant
    {
        uint256 commitment = commitments[msg.sender];
        if (commitment == 0) revert InsufficientFunds();
        
        // Reset commitment
        commitments[msg.sender] = 0;
        hasCommitted[msg.sender] = false;
        totalCommitted -= commitment;
        
        // Transfer back KRW
        krwToken.transfer(msg.sender, commitment);
        
        emit EmergencyWithdraw(msg.sender, commitment, reason);
    }
    
    /**
     * @dev Get investment group information
     */
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
    ) {
        return (
            startupName,
            startupDescription,
            targetAmount,
            totalCommitted,
            totalInvested,
            totalReturned,
            currentState,
            investmentDeadline,
            investors.length
        );
    }
    
    /**
     * @dev Get SAFE terms
     */
    function getSAFETerms() external view returns (SAFETerms memory) {
        return safeTerms;
    }
    
    /**
     * @dev Get investor list
     */
    function getInvestors() external view returns (address[] memory) {
        return investors;
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
     * @dev Extract symbol from company name (helper function)
     */
    function _getSymbolFromName(string memory name) internal pure returns (string memory) {
        bytes memory nameBytes = bytes(name);
        if (nameBytes.length >= 4) {
            bytes memory symbol = new bytes(4);
            for (uint i = 0; i < 4; i++) {
                symbol[i] = nameBytes[i];
            }
            return string(symbol);
        }
        return "LP";
    }
    
    /**
     * @dev Get contract version
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}