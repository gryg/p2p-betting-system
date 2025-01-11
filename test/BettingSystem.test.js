const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Betting System", function() {
    // This fixture deploys all contracts and returns them along with test accounts
    // and common testing parameters. It's run before each test, but uses snapshots
    // for efficiency.
    async function deployBettingSystemFixture() {
        const [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();
        
        // Deploy all contracts in the correct order
        const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
        const liquidityPool = await LiquidityPool.deploy();
        await liquidityPool.waitForDeployment();
        
        const minimumStake = ethers.parseEther("0.1");
        const Oracle = await ethers.getContractFactory("Oracle");
        const oracle = await Oracle.deploy(minimumStake);
        await oracle.waitForDeployment();
        
        const BettingPool = await ethers.getContractFactory("BettingPool");
        const bettingPool = await BettingPool.deploy(await oracle.getAddress());
        await bettingPool.waitForDeployment();
        
        // Define standard testing parameters
        const testParams = {
            minBet: ethers.parseEther("0.1"),
            maxBet: ethers.parseEther("1.0"),
            duration: 3600, // 1 hour in seconds
            standardBet: ethers.parseEther("0.5")
        };
        
        return {
            liquidityPool,
            oracle,
            bettingPool,
            owner,
            addr1,
            addr2,
            addr3,
            addr4,
            minimumStake,
            ...testParams
        };
    }

    describe("LiquidityPool", function() {
        it("Should allow adding liquidity", async function() {
            const { liquidityPool, addr1 } = await loadFixture(deployBettingSystemFixture);
            const amount = ethers.parseEther("1.0");

            await expect(liquidityPool.connect(addr1).addLiquidity({ value: amount }))
                .to.emit(liquidityPool, "LiquidityAdded")
                .withArgs(addr1.address, amount);

            expect(await liquidityPool.getLiquidityShare(addr1.address)).to.equal(amount);
            expect(await liquidityPool.getAvailableLiquidity()).to.equal(amount);
        });

        it("Should allow removing liquidity", async function() {
            const { liquidityPool, addr1 } = await loadFixture(deployBettingSystemFixture);
            const amount = ethers.parseEther("1.0");

            await liquidityPool.connect(addr1).addLiquidity({ value: amount });
            await expect(liquidityPool.connect(addr1).removeLiquidity(amount))
                .to.emit(liquidityPool, "LiquidityRemoved")
                .withArgs(addr1.address, amount);

            expect(await liquidityPool.getLiquidityShare(addr1.address)).to.equal(0);
        });

        it("Should prevent removing more than contributed", async function() {
            const { liquidityPool, addr1 } = await loadFixture(deployBettingSystemFixture);
            const amount = ethers.parseEther("1.0");

            await liquidityPool.connect(addr1).addLiquidity({ value: amount });
            await expect(
                // liquidityPool.connect(addr1).removeLiquidity(amount.mul(2))
                liquidityPool.connect(addr1).removeLiquidity(amount * 2n)
            ).to.be.revertedWith("Insufficient shares");
        });
    });

    describe("Oracle", function() {
        it("Should require minimum stake", async function() {
            const { oracle, addr1 } = await loadFixture(deployBettingSystemFixture);
            const lowStake = ethers.parseEther("0.05");
            const betId = 0;  // Add this line to define betId
            
            await oracle.initializeOracle(betId);

            await expect(
                oracle.connect(addr1).stake(0, { value: lowStake })
            ).to.be.revertedWith("Insufficient stake");
        });

        it("Should handle correct staking process", async function() {
            const { oracle, addr1, minimumStake } = await loadFixture(deployBettingSystemFixture);
            const betId = 0;
            await oracle.initializeOracle(betId);

            await expect(oracle.connect(addr1).stake(betId, { value: minimumStake }))
                .to.emit(oracle, "OracleStaked")
                .withArgs(betId, addr1.address, minimumStake);
        });

        it("Should prevent duplicate staking", async function() {
            const { oracle, addr1, minimumStake } = await loadFixture(deployBettingSystemFixture);
            const betId = 0;
            await oracle.initializeOracle(betId);

            await oracle.connect(addr1).stake(betId, { value: minimumStake });
            await expect(
                oracle.connect(addr1).stake(betId, { value: minimumStake })
            ).to.be.revertedWith("Already staked");
        });

        it("Should handle voting and consensus correctly", async function() {
            const { oracle, addr1, addr2, addr3, minimumStake } = await loadFixture(deployBettingSystemFixture);
            const betId = 0;
        
            // Initialize the oracle
            await oracle.initializeOracle(betId);
        
            // Set up oracles during staking period
            for (const addr of [addr1, addr2, addr3]) {
                await oracle.connect(addr).stake(betId, { value: minimumStake });
            }
        
            // Fast forward past staking period
            await time.increase(24 * 60 * 60 + 1); // Move past 1 day
        
            // End staking period
            await oracle.endStakingPeriod(betId);
        
            // Now voting can begin
            await oracle.connect(addr1).vote(betId, true);
            await oracle.connect(addr2).vote(betId, true);
        
            // Third vote should trigger consensus
            await expect(oracle.connect(addr3).vote(betId, true))
                .to.emit(oracle, "ConsensusReached")
                .withArgs(betId, true);
        
            const [outcome, finalized] = await oracle.getConsensus(betId);
            expect(finalized).to.be.true;
            expect(outcome).to.be.true;
        });

        it("Should properly slash incorrect votes", async function() {
            const { oracle, addr1, addr2, addr3, minimumStake } = await loadFixture(deployBettingSystemFixture);
            const betId = 0;
        
            // Initialize the oracle
            await oracle.initializeOracle(betId);
        
            // Record initial balances
            const initialBalances = await Promise.all([
                addr1.provider.getBalance(addr1.address),
                addr2.provider.getBalance(addr2.address),
                addr3.provider.getBalance(addr3.address)
            ]);
        
            // Setup stakes during staking period
            for (const addr of [addr1, addr2, addr3]) {
                await oracle.connect(addr).stake(betId, { value: minimumStake });
            }
        
            // Fast forward past staking period
            await time.increase(24 * 60 * 60 + 1);
            await oracle.endStakingPeriod(betId);
        
            // Now proceed with voting
            await oracle.connect(addr1).vote(betId, true);
            await oracle.connect(addr2).vote(betId, true);
            await oracle.connect(addr3).vote(betId, false); // Wrong vote
        
            // Check balances after slashing
            const finalBalances = await Promise.all([
                addr1.provider.getBalance(addr1.address),
                addr2.provider.getBalance(addr2.address),
                addr3.provider.getBalance(addr3.address)
            ]);
        
            // Verify addr3's stake was slashed
            expect(finalBalances[2]).to.be.lessThan(initialBalances[2] - minimumStake);
        });
    });

    describe("BettingPool", function() {
        describe("Bet Creation and Joining", function() {
            it("Should create a bet correctly", async function() {
                const { bettingPool, addr1, minBet, maxBet, duration } = await loadFixture(deployBettingSystemFixture);
                const betAmount = ethers.parseEther("0.5");

                await expect(
                    bettingPool.connect(addr1).createBet(
                        "Will ETH reach $5000?",
                        minBet,
                        maxBet,
                        duration,
                        { value: betAmount }
                    )
                ).to.emit(bettingPool, "BetCreated");

                const betDetails = await bettingPool.getBetDetails(0);
                expect(betDetails.totalAmountTrue).to.equal(betAmount);
            });

            it("Should allow taking positions", async function() {
                const { bettingPool, addr1, addr2, minBet, maxBet, duration } = await loadFixture(deployBettingSystemFixture);
                
                await bettingPool.connect(addr1).createBet(
                    "Test bet",
                    minBet,
                    maxBet,
                    duration,
                    { value: ethers.parseEther("0.5") }
                );

                await expect(
                    bettingPool.connect(addr2).takeBetPosition(0, false, { value: ethers.parseEther("0.3") })
                ).to.emit(bettingPool, "BetPositionTaken")
                .withArgs(0, addr2.address, false, ethers.parseEther("0.3"));
            });
        });

        describe("Bet Resolution and Payouts", function() {
            it("Should execute complete betting cycle with correct payouts", async function() {
                const { 
                    bettingPool, 
                    oracle, 
                    addr1, 
                    addr2, 
                    addr3, 
                    minimumStake, 
                    minBet, 
                    maxBet, 
                    duration 
                } = await loadFixture(deployBettingSystemFixture);

                // Record initial balances
                const initialBalances = await Promise.all([
                    addr1.provider.getBalance(addr1.address),
                    addr2.provider.getBalance(addr2.address),
                    addr3.provider.getBalance(addr3.address)
                ]);

                // Create and participate in bet
                await bettingPool.connect(addr1).createBet(
                    "Test bet",
                    minBet,
                    maxBet,
                    duration,
                    { value: ethers.parseEther("0.5") }
                );

                await bettingPool.connect(addr2).takeBetPosition(0, true, {
                    value: ethers.parseEther("0.5")
                });

                await bettingPool.connect(addr3).takeBetPosition(0, false, {
                    value: ethers.parseEther("1.0")
                });

                // Setup oracle consensus
                await oracle.initializeOracle(0);  // Initialize for betId 0

                for (const addr of [addr1, addr2, addr3]) {
                    await oracle.connect(addr).stake(0, { value: minimumStake });
                }

                // Fast forward past staking period
                await time.increase(24 * 60 * 60 + 1);
                await oracle.endStakingPeriod(0);

                // Now proceed with voting
                await oracle.connect(addr1).vote(0, true);
                await oracle.connect(addr2).vote(0, true);
                await oracle.connect(addr3).vote(0, true);

                // Time travel to end betting period
                await time.increase(duration + 1);

                // Resolve bet
                await bettingPool.connect(addr1).resolveBet(0);

                // Check final balances
                const finalBalances = await Promise.all([
                    addr1.provider.getBalance(addr1.address),
                    addr2.provider.getBalance(addr2.address),
                    addr3.provider.getBalance(addr3.address)
                ]);

                // Verify winners received correct payouts
                // TRUE position won (addr1 and addr2)
                // Total pool is 2 ETH, should be split proportionally
                expect(finalBalances[0]).to.be.above(initialBalances[0]);
                expect(finalBalances[1]).to.be.above(initialBalances[1]);
                expect(finalBalances[2]).to.be.below(initialBalances[2]);
            });

            it("Should prevent bet resolution before end time", async function() {
                const { bettingPool, addr1, minBet, maxBet, duration } = await loadFixture(deployBettingSystemFixture);

                await bettingPool.connect(addr1).createBet(
                    "Test bet",
                    minBet,
                    maxBet,
                    duration,
                    { value: ethers.parseEther("0.5") }
                );

                await expect(
                    bettingPool.connect(addr1).resolveBet(0)
                ).to.be.revertedWithCustomError(bettingPool, "BettingPeriodActive");
            });
        });
    });
});