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
}
