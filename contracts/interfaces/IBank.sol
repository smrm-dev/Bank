// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IBank {
    event LoanTook(
        address recipient,
        uint256 loanId,
        uint256 collateralValue,
        uint256 amount
    );

    event LoanSettled(
        address recipient,
        uint256 loanId,
        uint256 payback,
        uint256 amount
    );

    event CollateralIncreased(
        address recipient,
        uint256 loanId,
        uint256 collateral
    );

    event CollateralDecreased(
        address recipient,
        uint256 loanId,
        uint256 collateral
    );

    enum LoanState {
        UNDEFINED,
        ACTIVE,
        UNDER_LIQUIDATION,
        LIQUIDATED,
        SETTLED
    }

    struct Loan {
        address recipient;
        uint256 collateral;
        uint256 amount;
        LoanState state;
        uint256 liquidationId;
    }
}
