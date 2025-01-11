// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILiquidityPool {
    function addLiquidity() external payable;
    function removeLiquidity(uint256 amount) external;
    function getAvailableLiquidity() external view returns (uint256);
    function getLiquidityShare(address provider) external view returns (uint256);
}