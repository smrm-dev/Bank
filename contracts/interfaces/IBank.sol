// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IBank {
    event LoanTook(
        address recipient,
        uint256 loanId,
        uint256 collateralValue,
        uint256 amount
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
    }
}
