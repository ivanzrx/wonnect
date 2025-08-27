// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title KRWStablecoin
 * @dev KRW-pegged stablecoin for WonConnect platform
 * @notice This contract manages a KRW stablecoin for seamless cross-border investment
 */
contract KRWStablecoin is ERC20, ERC20Permit, Ownable, ReentrancyGuard, Pausable {
    /// @dev Mapping of authorized minters
    mapping(address => bool) public minters;
    
    /// @dev Mapping of authorized burners
    mapping(address => bool) public burners;
    
    /// @dev Platform treasury address for fee collection
    address public treasury;
    
    /// @dev Exchange rate precision (1e18 for 18 decimal places)
    uint256 public constant PRECISION = 1e18;
    
    /// @dev Maximum supply cap (100 billion KRW)
    uint256 public constant MAX_SUPPLY = 100_000_000_000 * 1e18;
    
    /// Events
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);
    event BurnerAdded(address indexed burner);
    event BurnerRemoved(address indexed burner);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event EmergencyMint(address indexed to, uint256 amount, string reason);
    
    /// Errors
    error Unauthorized();
    error InvalidAddress();
    error MaxSupplyExceeded();
    error InsufficientBalance();
    
    /// Modifiers
    modifier onlyMinter() {
        if (!minters[msg.sender]) revert Unauthorized();
        _;
    }
    
    modifier onlyBurner() {
        if (!burners[msg.sender]) revert Unauthorized();
        _;
    }
    
    modifier validAddress(address _address) {
        if (_address == address(0)) revert InvalidAddress();
        _;
    }
    
    /**
     * @dev Constructor
     * @param _treasury Initial treasury address
     */
    constructor(
        address _treasury
    ) 
        ERC20("Korean Won Stablecoin", "KRW") 
        ERC20Permit("Korean Won Stablecoin")
        Ownable(msg.sender)
        validAddress(_treasury)
    {
        treasury = _treasury;
        
        // Set initial minters and burners (owner can manage these)
        minters[msg.sender] = true;
        burners[msg.sender] = true;
        
        emit MinterAdded(msg.sender);
        emit BurnerAdded(msg.sender);
    }
    
    /**
     * @dev Mint new KRW tokens
     * @param to Address to mint tokens to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) 
        external 
        onlyMinter 
        whenNotPaused 
        nonReentrant
        validAddress(to)
    {
        if (totalSupply() + amount > MAX_SUPPLY) revert MaxSupplyExceeded();
        _mint(to, amount);
    }
    
    /**
     * @dev Burn KRW tokens
     * @param from Address to burn tokens from
     * @param amount Amount to burn
     */
    function burn(address from, uint256 amount) 
        external 
        onlyBurner 
        whenNotPaused 
        nonReentrant
        validAddress(from)
    {
        if (balanceOf(from) < amount) revert InsufficientBalance();
        _burn(from, amount);
    }
    
    /**
     * @dev Burn KRW tokens from caller
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external whenNotPaused nonReentrant {
        if (balanceOf(msg.sender) < amount) revert InsufficientBalance();
        _burn(msg.sender, amount);
    }
    
    /**
     * @dev Emergency mint function for crisis situations
     * @param to Address to mint to
     * @param amount Amount to mint
     * @param reason Reason for emergency mint
     */
    function emergencyMint(
        address to, 
        uint256 amount, 
        string calldata reason
    ) 
        external 
        onlyOwner 
        validAddress(to)
    {
        if (totalSupply() + amount > MAX_SUPPLY) revert MaxSupplyExceeded();
        _mint(to, amount);
        emit EmergencyMint(to, amount, reason);
    }
    
    /**
     * @dev Add authorized minter
     * @param minter Address to add as minter
     */
    function addMinter(address minter) 
        external 
        onlyOwner 
        validAddress(minter)
    {
        minters[minter] = true;
        emit MinterAdded(minter);
    }
    
    /**
     * @dev Remove authorized minter
     * @param minter Address to remove as minter
     */
    function removeMinter(address minter) external onlyOwner {
        minters[minter] = false;
        emit MinterRemoved(minter);
    }
    
    /**
     * @dev Add authorized burner
     * @param burner Address to add as burner
     */
    function addBurner(address burner) 
        external 
        onlyOwner 
        validAddress(burner)
    {
        burners[burner] = true;
        emit BurnerAdded(burner);
    }
    
    /**
     * @dev Remove authorized burner
     * @param burner Address to remove as burner
     */
    function removeBurner(address burner) external onlyOwner {
        burners[burner] = false;
        emit BurnerRemoved(burner);
    }
    
    /**
     * @dev Update treasury address
     * @param newTreasury New treasury address
     */
    function updateTreasury(address newTreasury) 
        external 
        onlyOwner 
        validAddress(newTreasury)
    {
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
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
     * @dev Override transfer to add pause functionality
     */
    function transfer(address to, uint256 amount) 
        public 
        override 
        whenNotPaused 
        returns (bool) 
    {
        return super.transfer(to, amount);
    }
    
    /**
     * @dev Override transferFrom to add pause functionality
     */
    function transferFrom(address from, address to, uint256 amount) 
        public 
        override 
        whenNotPaused 
        returns (bool) 
    {
        return super.transferFrom(from, to, amount);
    }
    
    /**
     * @dev Get contract version
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}