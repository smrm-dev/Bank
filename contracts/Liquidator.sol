// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./interfaces/ILiquidator.sol";
import "./libraries/Error.sol";

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
        returns (uint256 collateral, address buyer)
    {}

    function palceBid() external {}
}
