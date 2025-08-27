# WonConnect

KRW stablecoin-based investment platform connecting overseas Korean and foreign investors with promising Korean startups.

## Overview

WonConnect solves the complex legal and operational barriers that prevent overseas investors from accessing Korean startup investment opportunities. By combining AngelList's proven syndicate model with Web3 technology and KRW stablecoin, we enable transparent, efficient, and accessible cross-border investment.

## Key Features

- **KRW Stablecoin Integration**: Eliminate forex complexity and currency risk
- **Private Syndicate Model**: SAFE contract-based non-security investment structure
- **Automated Profit Distribution**: Smart contract-based waterfall distribution with 8% hurdle rate
- **LP NFT Shares**: Tradeable investment positions with automatic profit distribution
- **Platform Fee Structure**: 1-3% brokerage fees + 20% carry interest on excess returns

## Business Model

### Target Market
- 750만 overseas Koreans seeking domestic investment opportunities
- Foreign investors interested in Korean startup ecosystem
- Korean startups needing overseas capital (currently only 7% foreign capital vs 80% in Israel)

### Revenue Streams
- Investment brokerage fees (1-3% based on deal size)
- Operating fees (5M KRW per deal)
- Carried interest (20% of profits above 8% hurdle rate)
- Exit bonuses (0.5-1.0% for exceptional returns)

## Technical Architecture

### Contracts
Smart contracts built with Foundry framework on Kaia blockchain.

#### Core Smart Contracts
- **WonConnectFactory.sol**: Main platform contract managing syndicates and fees
- **InvestmentGroup.sol**: Individual syndicate contracts with SAFE integration
- **KRWStablecoin.sol**: KRW-pegged stablecoin for all transactions
- **LPShareNFT.sol**: NFT representing investment shares with profit distribution

#### Investment Flow
1. Lead Investor creates investment syndicate for specific startup
2. Investors commit KRW stablecoin to participate
3. Platform mints LP NFTs representing investment shares
4. Funds transferred to SPV structure for legal compliance
5. Automated profit distribution via smart contracts on exit events

#### Profit Distribution Waterfall
1. Return of principal to LPs
2. 8% hurdle rate to LPs
3. 20% carry interest to GP and platform
4. Exit bonus for exceptional returns (>5x)
5. Remaining profits distributed by LP share percentage

### Web
Frontend application for user interaction with smart contracts.

*To be developed - will provide intuitive interface for investors and lead investors to interact with the platform.*

## Synergy with Kaia

### For Platform
- Stable KRW stablecoin infrastructure
- Access to existing Kaia user base
- Regulatory compliance support

### For Kaia
- Real-world utility for KRW stablecoin beyond trading
- New user acquisition from overseas investors
- First-mover advantage in Web3 investment market

### For Investors
- No forex risk or complexity
- Access to exclusive Korean startup deals
- Transparent, automated profit distribution
- Portfolio diversification with small amounts

## Development Setup

### Contracts
Smart contract development using Foundry framework.

```bash
# Navigate to contracts directory
cd contracts

# Install dependencies
forge install

# Compile contracts
forge build

# Run tests
forge test

# Deploy to Kaia blockchain
forge script script/Deploy.s.sol --rpc-url <KAIA_RPC_URL> --private-key <PRIVATE_KEY> --broadcast

# Run demo scenario
forge script script/Demo.s.sol --rpc-url <KAIA_RPC_URL> --private-key <PRIVATE_KEY> --broadcast
```

### Web
*Frontend development setup will be added when web application is implemented.*

## Project Structure

```
wonnect/
├── contracts/           # Smart contract development
│   ├── src/            # Smart contract source files
│   │   ├── KRWStablecoin.sol
│   │   ├── LPShareNFT.sol
│   │   ├── InvestmentGroup.sol
│   │   ├── WonConnectFactory.sol
│   │   └── interfaces/
│   ├── script/         # Deployment and demo scripts
│   ├── test/           # Contract tests
│   ├── lib/            # Foundry dependencies
│   ├── foundry.toml    # Foundry configuration
│   └── deployments/    # Deployment records
├── web/                # Frontend application (to be developed)
├── README.md           # Project documentation
└── CLAUDE.md           # Claude Code guidance
```

## License

MIT
