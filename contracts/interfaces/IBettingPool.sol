// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBettingPool {
    error MinimumBetTooLow();
    error MaximumBetInvalid();
    error BettingPeriodEnded();
    error BetAlreadyResolved();
    error InvalidBetAmount();
    error AlreadyParticipating();
    error BettingPeriodActive();
    error NoWinners();
    error OracleNotFinalized();

    event BetCreated(uint256 indexed betId, address creator, string description);
    event BetPositionTaken(uint256 indexed betId, address participant, bool position, uint256 amount);
    event BetResolved(uint256 indexed betId, bool outcome);
    event PayoutDistributed(uint256 indexed betId, address recipient, uint256 amount);

    function createBet(string calldata description, uint256 minimumBet, uint256 maximumBet, uint256 duration) external payable;
    function takeBetPosition(uint256 betId, bool position) external payable;
    function resolveBet(uint256 betId) external;
}
