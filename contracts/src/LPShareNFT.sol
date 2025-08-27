// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IKRW.sol";

/**
 * @title LPShareNFT
 * @dev NFT representing Limited Partner shares in investment groups
 * @notice Each NFT represents an investor's stake in a specific investment syndicate
 */
contract LPShareNFT is ERC721, ERC721Enumerable, Ownable, ReentrancyGuard, Pausable {
    /// @dev Token ID counter
    uint256 private _nextTokenId = 1;
    
    /// @dev KRW stablecoin contract
    IKRW public immutable krwToken;
    
    /// @dev Investment group address this NFT collection belongs to
    address public immutable investmentGroup;
    
    /// @dev Platform treasury for fee collection
    address public treasury;
    
    /// @dev Struct representing LP share information
    struct LPShare {
        uint256 investmentAmount;    // Original investment in KRW
        uint256 sharesOwned;         // Number of shares owned
        uint256 lastClaimTimestamp;  // Last profit distribution claim
        uint256 totalClaimed;        // Total amount claimed so far
        bool isActive;               // Whether share is still active
    }
    
    /// @dev Mapping from token ID to LP share info
    mapping(uint256 => LPShare) public lpShares;
    
    /// @dev Total investment amount across all shares
    uint256 public totalInvestment;
    
    /// @dev Total shares issued
    uint256 public totalShares;
    
    /// @dev Profit distribution pool
    uint256 public profitPool;
    
    /// @dev Per-share profit amount (scaled by 1e18)
    uint256 public profitPerShare;
    
    /// @dev Secondary market trading fee (basis points)
    uint256 public tradingFee = 250; // 2.5%
    
    /// Events
    event ShareMinted(
        uint256 indexed tokenId,
        address indexed investor,
        uint256 investmentAmount,
        uint256 sharesOwned
    );
    
    event ProfitDistributed(
        uint256 totalProfit,
        uint256 newProfitPerShare
    );
    
    event ProfitClaimed(
        uint256 indexed tokenId,
        address indexed investor,
        uint256 amount
    );
    
    event TradingFeeUpdated(uint256 oldFee, uint256 newFee);
    
    event ShareLiquidated(
        uint256 indexed tokenId,
        address indexed investor,
        uint256 amount
    );
    
    /// Errors
    error Unauthorized();
    error InvalidAmount();
    error InvalidTokenId();
    error ShareNotActive();
    error InsufficientProfits();
    error TransferRestricted();
    
    /// Modifiers
    modifier onlyInvestmentGroup() {
        if (msg.sender != investmentGroup) revert Unauthorized();
        _;
    }
    
    modifier validTokenId(uint256 tokenId) {
        if (_ownerOf(tokenId) == address(0)) revert InvalidTokenId();
        _;
    }
    
    modifier activeShare(uint256 tokenId) {
        if (!lpShares[tokenId].isActive) revert ShareNotActive();
        _;
    }
    
    /**
     * @dev Constructor
     * @param _krwToken KRW stablecoin contract address
     * @param _investmentGroup Investment group contract address
     * @param _treasury Treasury address
     * @param _name NFT collection name
     * @param _symbol NFT collection symbol
     */
    constructor(
        address _krwToken,
        address _investmentGroup,
        address _treasury,
        string memory _name,
        string memory _symbol
    ) 
        ERC721(_name, _symbol)
        Ownable(msg.sender)
    {
        krwToken = IKRW(_krwToken);
        investmentGroup = _investmentGroup;
        treasury = _treasury;
        
        // Token IDs start from 1
    }
    
    /**
     * @dev Mint LP share NFT to investor
     * @param investor Address of the investor
     * @param investmentAmount Amount invested in KRW
     * @param sharesOwned Number of shares owned
     */
    function mintShare(
        address investor,
        uint256 investmentAmount,
        uint256 sharesOwned
    ) 
        external 
        onlyInvestmentGroup 
        whenNotPaused 
        nonReentrant
        returns (uint256)
    {
        if (investor == address(0)) revert Unauthorized();
        if (investmentAmount == 0 || sharesOwned == 0) revert InvalidAmount();
        
        uint256 tokenId = _nextTokenId;
        _nextTokenId++;
        
        // Create LP share record
        lpShares[tokenId] = LPShare({
            investmentAmount: investmentAmount,
            sharesOwned: sharesOwned,
            lastClaimTimestamp: block.timestamp,
            totalClaimed: 0,
            isActive: true
        });
        
        // Update totals
        totalInvestment += investmentAmount;
        totalShares += sharesOwned;
        
        // Mint NFT
        _safeMint(investor, tokenId);
        
        emit ShareMinted(tokenId, investor, investmentAmount, sharesOwned);
        
        return tokenId;
    }
    
    /**
     * @dev Distribute profits to all LP share holders
     * @param totalProfit Total profit amount to distribute
     */
    function distributeProfits(uint256 totalProfit) 
        external 
        onlyInvestmentGroup 
        whenNotPaused 
        nonReentrant
    {
        if (totalProfit == 0) revert InvalidAmount();
        if (totalShares == 0) return; // No shares to distribute to
        
        profitPool += totalProfit;
        profitPerShare += (totalProfit * 1e18) / totalShares;
        
        emit ProfitDistributed(totalProfit, profitPerShare);
    }
    
    /**
     * @dev Claim profits for a specific LP share
     * @param tokenId Token ID to claim profits for
     */
    function claimProfits(uint256 tokenId) 
        external 
        validTokenId(tokenId)
        activeShare(tokenId)
        whenNotPaused 
        nonReentrant
        returns (uint256)
    {
        address owner = ownerOf(tokenId);
        if (msg.sender != owner) revert Unauthorized();
        
        LPShare storage share = lpShares[tokenId];
        
        // Calculate claimable profit
        uint256 totalEarned = (share.sharesOwned * profitPerShare) / 1e18;
        uint256 claimable = totalEarned - share.totalClaimed;
        
        if (claimable == 0) return 0;
        if (claimable > profitPool) revert InsufficientProfits();
        
        // Update records
        share.totalClaimed += claimable;
        share.lastClaimTimestamp = block.timestamp;
        profitPool -= claimable;
        
        // Transfer KRW to investor
        krwToken.transfer(owner, claimable);
        
        emit ProfitClaimed(tokenId, owner, claimable);
        
        return claimable;
    }
    
    /**
     * @dev Get claimable profit amount for a token
     * @param tokenId Token ID to check
     */
    function getClaimableProfit(uint256 tokenId) 
        external 
        view 
        validTokenId(tokenId)
        returns (uint256)
    {
        LPShare storage share = lpShares[tokenId];
        if (!share.isActive) return 0;
        
        uint256 totalEarned = (share.sharesOwned * profitPerShare) / 1e18;
        uint256 claimable = totalEarned - share.totalClaimed;
        
        return claimable > profitPool ? profitPool : claimable;
    }
    
    /**
     * @dev Liquidate LP share (for exit events)
     * @param tokenId Token ID to liquidate
     * @param liquidationAmount Amount to pay for liquidation
     */
    function liquidateShare(uint256 tokenId, uint256 liquidationAmount) 
        external 
        onlyInvestmentGroup 
        validTokenId(tokenId)
        activeShare(tokenId)
        whenNotPaused 
        nonReentrant
    {
        address owner = ownerOf(tokenId);
        LPShare storage share = lpShares[tokenId];
        
        // Claim any remaining profits first
        uint256 totalEarned = (share.sharesOwned * profitPerShare) / 1e18;
        uint256 remainingProfits = totalEarned - share.totalClaimed;
        
        if (remainingProfits > 0 && remainingProfits <= profitPool) {
            profitPool -= remainingProfits;
            liquidationAmount += remainingProfits;
        }
        
        // Mark share as inactive
        share.isActive = false;
        
        // Update totals
        totalInvestment -= share.investmentAmount;
        totalShares -= share.sharesOwned;
        
        // Transfer liquidation amount
        if (liquidationAmount > 0) {
            krwToken.transfer(owner, liquidationAmount);
        }
        
        emit ShareLiquidated(tokenId, owner, liquidationAmount);
    }
    
    /**
     * @dev Update trading fee
     * @param newFee New trading fee in basis points
     */
    function updateTradingFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee too high"); // Max 10%
        uint256 oldFee = tradingFee;
        tradingFee = newFee;
        emit TradingFeeUpdated(oldFee, newFee);
    }
    
    /**
     * @dev Override transfer to handle secondary market fees
     */
    function transferFrom(address from, address to, uint256 tokenId) 
        public 
        override(ERC721, IERC721)
        whenNotPaused 
    {
        if (!lpShares[tokenId].isActive) revert ShareNotActive();
        
        // Collect trading fee on secondary market transactions
        if (from != address(0) && to != address(0) && from != investmentGroup) {
            LPShare storage share = lpShares[tokenId];
            uint256 fee = (share.investmentAmount * tradingFee) / 10000;
            
            if (fee > 0) {
                krwToken.transferFrom(to, treasury, fee);
            }
        }
        
        super.transferFrom(from, to, tokenId);
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
     * @dev Override required by Solidity
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }
    
    /**
     * @dev Override required by Solidity
     */
    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }
    
    /**
     * @dev Override required by Solidity
     */
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC721, ERC721Enumerable) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
    
    /**
     * @dev Get LP share information
     * @param tokenId Token ID to query
     */
    function getShareInfo(uint256 tokenId) 
        external 
        view 
        validTokenId(tokenId)
        returns (
            uint256 investmentAmount,
            uint256 sharesOwned,
            uint256 lastClaimTimestamp,
            uint256 totalClaimed,
            bool isActive,
            uint256 claimableProfit
        )
    {
        LPShare storage share = lpShares[tokenId];
        uint256 totalEarned = (share.sharesOwned * profitPerShare) / 1e18;
        uint256 claimable = totalEarned > share.totalClaimed ? 
                           totalEarned - share.totalClaimed : 0;
        
        return (
            share.investmentAmount,
            share.sharesOwned,
            share.lastClaimTimestamp,
            share.totalClaimed,
            share.isActive,
            claimable > profitPool ? profitPool : claimable
        );
    }
    
    /**
     * @dev Get contract version
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}