// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "./Dollar.sol";
import "./libraries/Error.sol";
import "./interfaces/IBank.sol";

contract Bank is IBank, AccessControl {
    uint256 public lastLoanId;
    address public dollar;
    address public liquidator;
    uint256 public liquidationDuration;

    mapping(uint256 => Loan) public loans;

    bytes32 public constant SETTER_ROLE = keccak256("SETTER_ROLE");

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
        liquidationDuration = 7200; // = 2 hours

        _grantRole(SETTER_ROLE, msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setLiquidator(address liquidator_) external onlyRole(SETTER_ROLE) {
        liquidator = liquidator_;
    }

    function setLiquidationDuration(uint256 liquidationDuration_)
        external
        onlyRole(SETTER_ROLE)
    {
        liquidationDuration = liquidationDuration_;
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

    function liquidate(uint256 loanId)
        external
        isInCorrectState(loanId, LoanState.ACTIVE)
    {
        Loan storage loan = loans[loanId];
        require(
            loan.collateral < minCollateral(loan.amount),
            Error.SUFFICIENT_COLLATERAL
        );
        loan.state = LoanState.UNDER_LIQUIDATION;
        ILiquidator(liquidator).startLiquidation(
            loanId,
            loan.collateral,
            loan.amount,
            liquidationDuration
        );
    }

    function liquidated() external {}
}
