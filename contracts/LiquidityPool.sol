// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ILiquidityPool.sol";

contract LiquidityPool is ILiquidityPool, ReentrancyGuard, Ownable {
    mapping(address => uint256) private liquidityShares;
    uint256 private totalLiquidity;

    event LiquidityAdded(address provider, uint256 amount);
    event LiquidityRemoved(address provider, uint256 amount);

    // Pass msg.sender to the Ownable constructor
    constructor() Ownable(msg.sender) {}

    function addLiquidity() external payable override nonReentrant {
        require(msg.value > 0, "Must provide liquidity");
       
        liquidityShares[msg.sender] += msg.value;
        totalLiquidity += msg.value;
       
        emit LiquidityAdded(msg.sender, msg.value);
    }

    function removeLiquidity(uint256 amount) external override nonReentrant {
        require(liquidityShares[msg.sender] >= amount, "Insufficient shares");
        require(totalLiquidity >= amount, "Insufficient pool liquidity");
       
        liquidityShares[msg.sender] -= amount;
        totalLiquidity -= amount;
       
        payable(msg.sender).transfer(amount);
        emit LiquidityRemoved(msg.sender, amount);
    }

    function getAvailableLiquidity() external view override returns (uint256) {
        return totalLiquidity;
    }

    function getLiquidityShare(address provider) external view override returns (uint256) {
        return liquidityShares[provider];
    }
}