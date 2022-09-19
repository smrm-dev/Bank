// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract PriceFeed {
    int256 public price;

    constructor(int256 price_) {
        price = price_;
    }

    function decimals() external pure returns (uint8) {
        return uint8(8);
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (uint80(0), price, uint256(0), uint256(0), uint80(0));
    }
}
