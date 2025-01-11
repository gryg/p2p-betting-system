// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);

    // Deploy LiquidityPool
    const LiquidityPool = await hre.ethers.getContractFactory("LiquidityPool");
    const liquidityPool = await LiquidityPool.deploy();
    await liquidityPool.deployed();
    console.log("LiquidityPool deployed to:", liquidityPool.address);

    // Deploy OracleManager
    const minimumStake = hre.ethers.utils.parseEther("0.1"); // 0.1 ETH minimum stake
    const OracleManager = await hre.ethers.getContractFactory("OracleManager");
    const oracleManager = await OracleManager.deploy(minimumStake);
    await oracleManager.deployed();
    console.log("OracleManager deployed to:", oracleManager.address);

    // Deploy BettingPool
    const BettingPool = await hre.ethers.getContractFactory("BettingPool");
    const bettingPool = await BettingPool.deploy(oracleManager.address, liquidityPool.address);
    await bettingPool.deployed();
    console.log("BettingPool deployed to:", bettingPool.address);

    // Log deployment details
    console.log("\nDeployment Summary:");
    console.log("==================");
    console.log(`LiquidityPool: ${liquidityPool.address}`);
    console.log(`OracleManager: ${oracleManager.address}`);
    console.log(`BettingPool: ${bettingPool.address}`);
    console.log(`Minimum Stake: ${hre.ethers.utils.formatEther(minimumStake)} ETH`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
