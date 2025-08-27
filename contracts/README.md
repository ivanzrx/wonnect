# WonConnect Smart Contracts

Smart contract implementation for WonConnect platform on Kaia blockchain.

## Smart Contracts Overview

### KRWStablecoin.sol
KRW-pegged ERC20 stablecoin with controlled minting/burning.

**Key Functions:**
- `mint(address to, uint256 amount)` - Mint KRW tokens to address
- `burn(address from, uint256 amount)` - Burn KRW tokens from address  
- `addMinter(address minter)` - Add authorized minter
- `addBurner(address burner)` - Add authorized burner
- `pause()` / `unpause()` - Emergency pause functionality

### WonConnectFactory.sol
Main platform contract managing investment groups and platform operations.

**Key Functions:**
- `createInvestmentGroup(...)` - Create new investment syndicate
- `verifyLeadInvestor(address, string, string)` - Verify GP credentials
- `purchaseSubscription(string tierName, uint256 months)` - Buy platform subscription
- `collectBrokerageFee(uint256 amount)` - Collect platform fees
- `updateFeeRates(uint256, uint256, uint256)` - Update platform fee structure

### InvestmentGroup.sol
Individual syndicate contract for startup investments with SAFE integration.

**Key Functions:**
- `commitInvestment(uint256 amount)` - Commit KRW investment to group
- `executeInvestment()` - Deploy capital to startup (GP only)
- `processExit(uint256 exitAmount)` - Process exit returns and distribute profits
- `emergencyWithdraw(string reason)` - Emergency withdrawal before execution
- `getGroupInfo()` - Get syndicate status and financial info

### LPShareNFT.sol
ERC721 NFT representing LP investment shares with automatic profit distribution.

**Key Functions:**
- `mintShare(address, uint256, uint256)` - Mint LP NFT for investment
- `distributeProfits(uint256 totalProfit)` - Distribute profits to all NFT holders
- `claimProfits(uint256 tokenId)` - Claim profits for specific NFT
- `liquidateShare(uint256 tokenId, uint256 amount)` - Liquidate share on exit
- `getClaimableProfit(uint256 tokenId)` - Check claimable profit amount
- `getShareInfo(uint256 tokenId)` - Get detailed share information

## Development Commands

```bash
# Compile contracts
forge build

# Run tests
forge test

# Deploy to Kaia
forge script script/Deploy.s.sol --rpc-url <KAIA_RPC> --private-key <PRIVATE_KEY> --broadcast

# Run demo
forge script script/Demo.s.sol --rpc-url <KAIA_RPC> --private-key <PRIVATE_KEY> --broadcast
```

## Contract Interaction Flow

1. **Platform Setup**: Deploy KRW stablecoin and Factory contracts
2. **GP Registration**: Verify lead investors through Factory
3. **Group Creation**: GP creates investment group via Factory
4. **Investment**: LPs commit KRW and receive LP NFTs
5. **Execution**: GP executes investment to startup
6. **Distribution**: Automated profit distribution on exit events

## Security Features

- **ReentrancyGuard**: Protection against reentrancy attacks
- **Pausable**: Emergency pause functionality
- **Access Control**: Role-based permissions (Owner, Minter, Burner, GP)
- **Validation**: Input validation and error handling
- **Safe Math**: Overflow protection with Solidity 0.8.20+