// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Dollar.sol";
import "./libraries/Error.sol";
import "./interfaces/IBank.sol";

contract Bank is IBank {
    uint256 public lastLoanId;
    address public dollar;
    mapping(uint256 => Loan) public loans;

    modifier isNotZero(uint256 number) {
        require(number != 0, Error.INVALID_AMOUNT);
        _;
    }

    modifier isInCorrectState(uint256 loanId, LoanState needState) {
        require(loans[loanId].state == needState, Error.INVALID_LOAN_STATE);
        _;
    }

    constructor(address dollar_) {
        dollar = dollar_;
    }

    function minCollateral(uint256 amount) public pure returns (uint256) {
        return amount;
    }

    function takeOutLoan(uint256 amount)
        external
        payable
        isNotZero(amount)
        isNotZero(msg.value)
    {
        require(
            minCollateral(amount) <= msg.value,
            Error.INSUFFICIENT_COLLATERAL
        );

        uint256 loanId = ++lastLoanId;

        loans[loanId] = Loan({
            recipient: msg.sender,
            collateral: msg.value,
            amount: amount,
            state: LoanState.ACTIVE
        });

        emit LoanTook(msg.sender, loanId, msg.value, amount);
        Dollar(dollar).mint(msg.sender, amount);
    }

    function settleLoan(uint256 loanId, uint256 amount)
        external
        isInCorrectState(loanId, LoanState.ACTIVE)
        isNotZero(amount)
    {
        Loan storage loan = loans[loanId];
        require(amount <= loan.amount, Error.INVALID_AMOUNT);
        require(
            Dollar(dollar).transferFrom(msg.sender, address(this), amount),
            Error.INSUFFICIENT_ALLOWANCE
        );
        uint256 payback = (loan.collateral * amount) / loan.amount;
        Dollar(dollar).burn(amount);
        loan.collateral -= payback;
        loan.amount -= amount;
        if (loan.amount == 0) {
            loan.state = LoanState.SETTLED;
        }
        emit LoanSettled(loan.recipient, loanId, payback, amount);
        payable(loan.recipient).transfer(payback);
    }

    function liquidate() external {}

    function liquidated() external {}
}
