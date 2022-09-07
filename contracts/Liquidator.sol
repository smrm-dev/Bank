// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Liquidator {
    address public bank;
    address public dollar;

    constructor(address bank_, address dollar_) {
        bank = bank_;
        dollar = dollar_;
    }

    function startLiquidation() external {}

    function stopLiquidation() external {}

    function palceBid() external {}
}
