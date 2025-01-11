// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IOracle.sol";

contract Oracle is IOracle, ReentrancyGuard, Ownable {
    struct Vote {
        bool outcome;
        uint256 weight;
    }

    struct BetOracle {
        bool stakingPeriodEnded;
        bool finalized;
        uint256 stakingEndTime;
        uint256 totalStaked;
        uint256 votesFor;
        uint256 votesAgainst;
        address[] stakedOracles;
        mapping(address => uint256) stakes;
        mapping(address => Vote) votes;
    }

    uint256 public immutable STAKING_PERIOD = 1 days;  // Example duration

    uint256 public immutable minimumStake;
    mapping(uint256 => BetOracle) private betOracles;

    constructor(uint256 _minimumStake) Ownable(msg.sender) {
        minimumStake = _minimumStake;
    }

    function initializeOracle(uint256 betId) external {
        BetOracle storage betOracle = betOracles[betId];
        betOracle.stakingEndTime = block.timestamp + STAKING_PERIOD;
    }

    function stake(uint256 betId) external payable override nonReentrant {
        BetOracle storage betOracle = betOracles[betId];
        require(betOracle.stakingEndTime > 0, "Oracle not initialized");
        require(block.timestamp < betOracle.stakingEndTime, "Staking period ended");
        require(msg.value >= minimumStake, "Insufficient stake");
        require(betOracle.stakes[msg.sender] == 0, "Already staked");

        betOracle.stakes[msg.sender] = msg.value;
        betOracle.totalStaked += msg.value;
        betOracle.stakedOracles.push(msg.sender);

        emit OracleStaked(betId, msg.sender, msg.value);
    }

    function endStakingPeriod(uint256 betId) external {
        BetOracle storage betOracle = betOracles[betId];
        require(block.timestamp >= betOracle.stakingEndTime, "Staking period active");
        require(!betOracle.stakingPeriodEnded, "Staking already ended");
        
        betOracle.stakingPeriodEnded = true;
    }

    function vote(uint256 betId, bool outcome) external override nonReentrant {
        BetOracle storage betOracle = betOracles[betId];
        require(betOracle.stakingPeriodEnded, "Staking period not ended");
        require(!betOracle.finalized, "Oracle voting finished");
        require(betOracle.stakes[msg.sender] > 0, "Not staked");
        require(betOracle.votes[msg.sender].weight == 0, "Already voted");

        uint256 weight = betOracle.stakes[msg.sender];
        betOracle.votes[msg.sender] = Vote(outcome, weight);

        if (outcome) {
            betOracle.votesFor += weight;
        } else {
            betOracle.votesAgainst += weight;
        }

        emit OracleVoted(betId, msg.sender, outcome);
        checkConsensus(betId);
    }

    function checkConsensus(uint256 betId) private {
        BetOracle storage betOracle = betOracles[betId];
        uint256 totalVotes = betOracle.votesFor + betOracle.votesAgainst;

        // Require 75% participation for consensus
        if (totalVotes >= (betOracle.totalStaked * 3) / 4) {
            betOracle.finalized = true;
            bool consensusOutcome = betOracle.votesFor > betOracle.votesAgainst;
            emit ConsensusReached(betId, consensusOutcome);
            slashStakes(betId, consensusOutcome);
        }
    }

    function slashStakes(uint256 betId, bool consensusOutcome) private {
        BetOracle storage betOracle = betOracles[betId];
        uint256 slashedAmount = 0;
        uint256 correctStakes = 0;
        
        // First pass: calculate totals using actual staked oracles
        for (uint256 i = 0; i < betOracle.stakedOracles.length; i++) {
            address oracle = betOracle.stakedOracles[i];
            
            if (betOracle.votes[oracle].weight == 0) continue;
            
            bool votedWithConsensus = betOracle.votes[oracle].outcome == consensusOutcome;
            
            if (!votedWithConsensus) {
                uint256 penalty = betOracle.stakes[oracle] / 2;
                slashedAmount += penalty;
                betOracle.stakes[oracle] -= penalty;
                emit StakeSlashed(oracle, penalty);
            } else {
                correctStakes += betOracle.stakes[oracle];
            }
        }
        
        // If there were slashed stakes and correct voters, distribute rewards
        if (slashedAmount > 0 && correctStakes > 0) {
            // Second pass: distribute slashed amounts to correct voters
            for (uint160 i = 1; i <= 100; i++) {
                address oracle = address(uint160(uint256(keccak256(abi.encodePacked(betId, i)))));
                
                if (betOracle.stakes[oracle] > 0 && 
                    betOracle.votes[oracle].weight > 0 && 
                    betOracle.votes[oracle].outcome == consensusOutcome) {
                    
                    // Calculate reward proportional to their stake
                    uint256 reward = (slashedAmount * betOracle.stakes[oracle]) / correctStakes;
                    
                    // Add reward to their stake
                    betOracle.stakes[oracle] += reward;
                    
                    emit StakeRewarded(oracle, reward);
                }
            }
        }
        
        // Allow stake withdrawal for oracles that voted correctly
        for (uint160 i = 1; i <= 100; i++) {
            address oracle = address(uint160(uint256(keccak256(abi.encodePacked(betId, i)))));
            
            if (betOracle.stakes[oracle] > 0 && 
                betOracle.votes[oracle].weight > 0 && 
                betOracle.votes[oracle].outcome == consensusOutcome) {
                
                uint256 finalAmount = betOracle.stakes[oracle];
                betOracle.stakes[oracle] = 0; // Clear stake before transfer
                
                // Transfer stake plus rewards back to correct oracle
                (bool success, ) = payable(oracle).call{value: finalAmount}("");
                require(success, "Transfer failed");
                
                emit StakeWithdrawn(oracle, finalAmount);
            }
        }
    }

    function getConsensus(uint256 betId) external view override returns (bool outcome, bool finalized) {
        BetOracle storage betOracle = betOracles[betId];
        return (betOracle.votesFor > betOracle.votesAgainst, betOracle.finalized);
    }
}