# P2P Betting System

A decentralized peer-to-peer betting system implemented on Ethereum that allows users to create and participate in binary outcome bets with oracle-based resolution and decentralized liquidity provision.

## Architecture Overview

The system consists of three main smart contracts that work together:

1. BettingPool: Manages bet creation, participation, and payouts
2. Oracle: Handles outcome verification through a decentralized voting mechanism
3. LiquidityPool: Provides liquidity for the betting system

### System Flow

```
[User Creates Bet] → [Other Users Take Positions] → [Oracle Voting Period] → [Bet Resolution] → [Payout Distribution]
```

## Core Components

### BettingPool Contract

The BettingPool contract is the main entry point for users to interact with the betting system. It manages the lifecycle of bets from creation to resolution.

Key features:
- Bet creation with customizable parameters (minimum bet, maximum bet, duration)
- Position taking (True/False) with stake management
- Automated payout distribution based on oracle consensus
- Integration with Oracle contract for result verification

Betting Process:
1. Creator initiates a bet by specifying parameters and optional initial position
2. Participants can take positions until the betting period ends
3. After the betting period, the contract consults the Oracle for outcome
4. Winners receive proportional payouts from the total pool

### Oracle Contract

The Oracle contract provides decentralized outcome verification through a stake-weighted voting system.

Key features:
- Two-phase voting process (staking and voting)
- Stake-weighted consensus mechanism
- Slashing mechanism for incorrect votes
- Reward distribution for correct voters

Oracle Process:
1. Initialization with a staking period (default 24 hours)
2. Oracles stake ETH to participate
3. After staking period ends, voting begins
4. Consensus requires 75% stake-weighted participation
5. Incorrect voters get slashed, correct voters share rewards

### LiquidityPool Contract

The LiquidityPool contract manages system liquidity for bet settlement.

Key features:
- Liquidity provision tracking
- Share-based liquidity management
- Secure withdrawal mechanism

## State Transitions

### Bet States:
1. Created: Initial state when bet is created
2. Active: Accepting positions
3. Pending Resolution: Betting period ended, awaiting oracle consensus
4. Resolved: Final state after payout distribution

### Oracle States:
1. Initialized: Staking period begins
2. Staking Ended: Voting period begins
3. Finalized: Consensus reached and stakes settled

## Security Mechanisms

The system implements several security features:

1. ReentrancyGuard protection on all value-transferring functions
2. Stake-weighted voting to prevent Sybil attacks
3. Two-phase oracle process to ensure fair participation
4. Slashing mechanism to discourage malicious voting
5. Custom error handling for clear failure states

## Technical Implementation Details

### Bet Position Management

The system tracks positions using a struct that contains:
- Position flag (True/False)
- Stake amount
- Participation status

### Consensus Calculation

Oracle consensus is calculated as:
```solidity
totalVotes = votesFor + votesAgainst;
if (totalVotes >= (totalStaked * 3) / 4) {
    consensusOutcome = votesFor > votesAgainst;
}
```

### Payout Distribution

Payouts are calculated proportionally:
```solidity
share = (position.amount * totalPool) / winningPool
```

## Usage Example

```javascript
// Create a new bet
await bettingPool.createBet(
    "Will ETH reach $5000 by end of 2024?",
    minBet,
    maxBet,
    duration,
    { value: initialStake }
);

// Take a position
await bettingPool.takeBetPosition(betId, true, { value: stake });

// Participate as oracle
await oracle.initializeOracle(betId);
await oracle.stake(betId, { value: minimumStake });
await oracle.vote(betId, true);

// Resolve bet
await bettingPool.resolveBet(betId);
```

## Development and Testing

The system uses Hardhat for development and testing. To run:

```bash
npm install
npx hardhat compile
npx hardhat test
```

## Security Considerations

1. Oracle Manipulation: Mitigated through stake requirements and slashing
2. Front-running: Protected by minimum/maximum bet limits
3. Reentrancy: Prevented using OpenZeppelin's ReentrancyGuard
4. Stake Locking: Managed through explicit staking periods
5. Consensus Gaming: Addressed by requiring 75% participation

## Event Flow

The system emits events at key state transitions:

1. Bet Creation/Position Taking:
   - BetCreated(betId, creator, description)
   - BetPositionTaken(betId, participant, position, amount)

2. Oracle Operations:
   - OracleStaked(betId, staker, amount)
   - OracleVoted(betId, voter, outcome)
   - ConsensusReached(betId, outcome)

3. Payout Events:
   - PayoutDistributed(betId, winner, amount)

## Future Improvements

Potential enhancements to consider:

1. Multi-outcome betting support
2. Dynamic stake requirements based on bet size
3. Automated oracle selection mechanism
4. Integration with external price feeds
5. Partial position liquidation
6. Secondary market for betting positions