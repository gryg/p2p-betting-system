// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IOracle {
    event OracleStaked(uint256 indexed betId, address oracle, uint256 amount);
    event OracleVoted(uint256 indexed betId, address oracle, bool vote);
    event ConsensusReached(uint256 indexed betId, bool outcome);
    event StakeSlashed(address indexed oracle, uint256 amount);
    event StakeRewarded(address indexed oracle, uint256 amount);
    event StakeWithdrawn(address indexed oracle, uint256 amount);

    function stake(uint256 betId) external payable;
    function vote(uint256 betId, bool outcome) external;
    function getConsensus(uint256 betId) external view returns (bool outcome, bool finalized);
}