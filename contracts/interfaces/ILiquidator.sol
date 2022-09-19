// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ILiquidator {
    enum LiquidationState {
        ACTIVE,
        FINISHED
    }
    struct Liquidation {
        uint256 loanId;
        uint256 collateral;
        uint256 amount;
        uint256 endTime;
        address bestBidder;
        uint256 bestBid;
        LiquidationState state;
    }

    event LiquidationStarted(
        uint256 indexed liquidationId,
        uint256 indexed loanId,
        uint256 collateral,
        uint256 amount,
        uint256 endTime
    );

    function startLiquidation(
        uint256 loanId,
        uint256 collateral,
        uint256 amount,
        uint256 duration
    ) external returns (uint256 liquidationId);

    function stopLiquidation(uint256 liquidationId)
        external
        returns (uint256 collateral, address buyer);
}
