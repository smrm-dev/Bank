// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./libraries/Error.sol";
import "./interfaces/ILiquidator.sol";
import "./Dollar.sol";

contract Liquidator is ILiquidator {
    address public bank;
    address public dollar;

    uint256 public lastLiquidationId;
    mapping(uint256 => Liquidation) liquidations;

    constructor(address bank_, address dollar_) {
        bank = bank_;
        dollar = dollar_;
    }

    modifier onlyBank() {
        require(msg.sender == bank, Error.ONLY_BANK);
        _;
    }

    modifier onlyActive(uint256 liquidationId) {
        require(
            liquidations[liquidationId].state == LiquidationState.ACTIVE,
            Error.NOT_ACTIVE_LIQUIDATION
        );
        _;
    }

    function startLiquidation(
        uint256 loanId,
        uint256 collateral,
        uint256 amount,
        uint256 duration
    ) external onlyBank returns (uint256 liquidationId) {
        liquidationId = ++lastLiquidationId;
        uint256 endTime = duration + block.timestamp;
        liquidations[liquidationId] = Liquidation({
            loanId: loanId,
            collateral: collateral,
            amount: amount,
            endTime: endTime,
            bestBidder: address(0),
            bestBid: 0,
            state: LiquidationState.ACTIVE
        });
        emit LiquidationStarted(
            liquidationId,
            loanId,
            collateral,
            amount,
            endTime
        );
    }

    function stopLiquidation(uint256 liquidationId)
        external
        onlyBank
        returns (uint256 collateral, address buyer)
    {
        Liquidation storage liquidation = liquidations[liquidationId];
        require(liquidation.endTime <= block.timestamp, Error.OPEN_LIQUIDATION);
        require(liquidation.bestBid != 0, Error.NO_BID);
        liquidation.state = LiquidationState.FINISHED;
        Dollar(dollar).burn(liquidation.amount);
        emit LiquidationStopped(
            liquidationId,
            liquidation.loanId,
            liquidation.bestBid,
            liquidation.bestBidder
        );
        return (liquidation.bestBid, liquidation.bestBidder);
    }

    function placeBid(uint256 liquidationId, uint256 bidAmount)
        external
        onlyActive(liquidationId)
    {
        Liquidation storage liquidation = liquidations[liquidationId];
        uint256 maxBid = liquidation.bestBid != 0
            ? liquidation.bestBid - 1
            : liquidation.collateral;

        require(bidAmount <= maxBid, Error.INADEQUATE_BIDDING);
        Dollar(dollar).transferFrom(
            msg.sender,
            address(this),
            liquidation.amount
        );
        Dollar(dollar).transfer(liquidation.bestBidder, liquidation.amount);
        liquidation.bestBidder = msg.sender;
        liquidation.bestBid = bidAmount;
    }
}
