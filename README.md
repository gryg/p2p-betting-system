# P2P Betting System with Oracle Consensus

A decentralized peer-to-peer betting system implemented using smart contracts. This system features oracle-based consensus for determining bet outcomes and includes a liquidity pool mechanism for enhanced betting capabilities.

## Overview

For a detailed explanation of the system's logic and flow, please refer to our [Logic Flow Documentation](./README-logic-flow.md).

## Prerequisites

Before starting, make sure you have installed:
- Node.js (version 18.x LTS recommended)
- npm (Node Package Manager)
- Git

<!-- The project has been tested with these specific versions to ensure compatibility:
- Hardhat 2.22.17
- OpenZeppelin Contracts 5.2.0
- Ethers 6.13.5 -->

## Project Setup

### Initial Setup

First, clone the repository and install dependencies:

```bash
# Clone the repository
git clone https://github.com/gryg/p2p-betting-system

# Navigate to project directory
cd p2p-betting-system

# Install all required dependencies
npm install
```

### Environment Configuration

Create a `.env` file in your project root directory. While not required for local testing, this will be needed for deploying to test networks:

```env
# Network Configuration
INFURA_PROJECT_ID=your_infura_project_id
PRIVATE_KEY=your_wallet_private_key

# Contract Configuration
ORACLE_ADDRESS=deployed_oracle_contract_address
MINIMUM_BET_AMOUNT=100000000000000000  # 0.1 ETH in Wei

# Optional Configuration
ETHERSCAN_API_KEY=your_etherscan_api_key
REPORT_GAS=true
```

## Development

### Local Development

To start development, you can use the following commands:

```bash
# Start local Hardhat network
npx hardhat node

# Run tests
npx hardhat test

# Deploy contracts locally
npx hardhat run scripts/deploy.js --network localhost
```

### Testing

The project includes comprehensive tests for all smart contract functionality. Run the test suite using:

```bash
# Run all tests
npm test

# Run specific test file
npx hardhat test test/BettingSystem.test.js

# Run tests with gas reporting
REPORT_GAS=true npx hardhat test
```

## Common Issues and Solutions

### Node.js Version Warning

If you encounter the Node.js version warning:

```bash
Warning: Node.js version incompatibility detected
```

Solution: Use nvm (Node Version Manager) to switch to the recommended version:

```bash
nvm install 18
nvm use 18
```

### Logic-flow

Can be found at [Logic Flow](/README-logic-flow.md).

