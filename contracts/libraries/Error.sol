// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library Error {
    string public constant INVALID_AMOUNT = "INVALID_AMOUNT";
    string public constant INITIALIZED_BEFORE = "INITIALIZED_BEFORE";
    string public constant SUFFICIENT_COLLATERAL = "SUFFICIENT_COLLATERAL";
    string public constant INSUFFICIENT_COLLATERAL = "INSUFFICIENT_COLLATERAL";
    string public constant INSUFFICIENT_ALLOWANCE = "INSUFFICIENT_ALLOWANCE";
    string public constant ONLY_LOAN_OWNER = "ONLY_LOAN_OWNER";
    string public constant ONLY_LIQUIDATOR = "ONLY_LIQUIDATOR";
    string public constant ONLY_ORACLES = "ONLY_ORACLE";
    string public constant INVALID_LOAN_STATE = "INVALID_LOAN_STATE";
    string public constant EXCEEDED_MAX_LOAN = "EXCEEDED_MAX_LOAN";

    string public constant ONLY_BANK = "ONLY_BANK";
    string public constant NO_DEPOSIT = "NO_DEPOSIT";
    string public constant NOT_ACTIVE_LIQUIDATION = "NOT_ACTIVE_LIQUIDATION";
    string public constant OPEN_LIQUIDATION = "OPEN_LIQUIDATION";
    string public constant NO_BID = "NO_BID";
    string public constant INADEQUATE_BIDDING = "INADEQUATE_BIDDING";
    string public constant INSUFFICIENT_FUNDS = "INSUFFICIENT_FUNDS";
}
