// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBettingPool.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/ILiquidityPool.sol";

contract BettingPool is IBettingPool, ReentrancyGuard, Ownable {
    struct BetPosition {
        bool hasPosition;
        bool position;
        uint256 amount;
    }

    struct Bet {
        string description;
        uint256 minimumBet;
        uint256 maximumBet;
        uint256 endTime;
        bool resolved;
        uint256 totalAmountTrue;
        uint256 totalAmountFalse;
        mapping(address => BetPosition) positions;
    }

    mapping(uint256 => Bet) private bets;
    uint256 private nextBetId;
    IOracle public immutable oracle;

    constructor(address _oracle) Ownable(msg.sender) {
        oracle = IOracle(_oracle);
    }

    function createBet(
        string calldata description,
        uint256 minimumBet,
        uint256 maximumBet,
        uint256 duration
    ) external payable override nonReentrant {
        // Using custom errors instead of require statements
        if (minimumBet == 0) revert MinimumBetTooLow();
        if (maximumBet < minimumBet) revert MaximumBetInvalid();

        uint256 betId = nextBetId++;
        Bet storage newBet = bets[betId];

        newBet.description = description;
        newBet.minimumBet = minimumBet;
        newBet.maximumBet = maximumBet;
        newBet.endTime = block.timestamp + duration;

        // Handle initial bet if creator is betting
        if (msg.value > 0) {
            if (msg.value < minimumBet || msg.value > maximumBet) revert InvalidBetAmount();
            _takePosition(betId, true, msg.value);
        }

        emit BetCreated(betId, msg.sender, description);
    }

    function takeBetPosition(uint256 betId, bool position) external payable override nonReentrant {
        Bet storage bet = bets[betId];

        if (msg.value == 0) revert InvalidBetAmount();
        if (bet.resolved) revert BetAlreadyResolved();
        if (block.timestamp >= bet.endTime) revert BettingPeriodEnded();
        if (msg.value < bet.minimumBet || msg.value > bet.maximumBet) revert InvalidBetAmount();
        if (bet.positions[msg.sender].hasPosition) revert AlreadyParticipating();

        _takePosition(betId, position, msg.value);
    }

    function _takePosition(uint256 betId, bool position, uint256 amount) private {
        Bet storage bet = bets[betId];
        
        bet.positions[msg.sender] = BetPosition({
            hasPosition: true,
            position: position,
            amount: amount
        });

        if (position) {
            bet.totalAmountTrue += amount;
        } else {
            bet.totalAmountFalse += amount;
        }

        emit BetPositionTaken(betId, msg.sender, position, amount);
    }

    function resolveBet(uint256 betId) external override nonReentrant {
        Bet storage bet = bets[betId];
        
        if (block.timestamp < bet.endTime) revert BettingPeriodActive();
        if (bet.resolved) revert BetAlreadyResolved();

        (bool outcome, bool finalized) = oracle.getConsensus(betId);
        if (!finalized) revert OracleNotFinalized();

        bet.resolved = true;
        _distributePayout(betId, outcome);

        emit BetResolved(betId, outcome);
    }

    function _distributePayout(uint256 betId, bool outcome) private {
        Bet storage bet = bets[betId];
        
        uint256 totalPool = bet.totalAmountTrue + bet.totalAmountFalse;
        uint256 winningPool = outcome ? bet.totalAmountTrue : bet.totalAmountFalse;
        
        if (winningPool == 0) revert NoWinners();

        // Optimized payout distribution using fixed-size batches
        uint256 batchSize = 20;
        for (uint256 i = 0; i < batchSize; i++) {
            address participant = address(uint160(uint256(keccak256(abi.encodePacked(betId, i)))));
            BetPosition memory position = bet.positions[participant];
            
            if (position.hasPosition && position.position == outcome) {
                uint256 share = (position.amount * totalPool) / winningPool;
                (bool success, ) = participant.call{value: share}("");
                if (success) {
                    emit PayoutDistributed(betId, participant, share);
                }
            }
        }
    }

    function getBetDetails(uint256 betId) external view returns (
        string memory description,
        uint256 totalAmountTrue,
        uint256 totalAmountFalse,
        uint256 minimumBet,
        uint256 maximumBet,
        uint256 endTime,
        bool resolved
    ) {
        Bet storage bet = bets[betId];
        return (
            bet.description,
            bet.totalAmountTrue,
            bet.totalAmountFalse,
            bet.minimumBet,
            bet.maximumBet,
            bet.endTime,
            bet.resolved
        );
    }

    function getParticipantPosition(uint256 betId, address participant) external view returns (
        bool hasPosition,
        bool position,
        uint256 amount
    ) {
        BetPosition memory pos = bets[betId].positions[participant];
        return (pos.hasPosition, pos.position, pos.amount);
    }
}