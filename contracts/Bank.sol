// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "./Dollar.sol";
import "./libraries/Error.sol";
import "./interfaces/IBank.sol";
import "./interfaces/ILiquidator.sol";

contract Bank is IBank, AccessControl {
    uint256 public lastLoanId;
    address public dollar;
    address public priceFeed;
    uint256 public collateralRatio;
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

    constructor(
        address dollar_,
        address priceFeed_,
        uint256 collateralRatio_
    ) {
        dollar = dollar_;
        priceFeed = priceFeed_;
        collateralRatio = collateralRatio_;
        liquidationDuration = 7200; // = 2 hours

        _grantRole(SETTER_ROLE, msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setPriceFeed(address priceFeed_) external onlyRole(SETTER_ROLE) {
        priceFeed = priceFeed_;
    }

    function setCollateralRatio(uint256 collateralRatio_)
        external
        onlyRole(SETTER_ROLE)
    {
        collateralRatio = collateralRatio_;
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

    /**
     * Returns the latest price
     */
    function getLatestPrice() public view returns (int) {
        (, int price, , , ) = AggregatorV3Interface(priceFeed)
            .latestRoundData();
        return price;
    }

    function minCollateral(uint256 amount) public view returns (uint256) {
        uint256 min = (amount *
            1e18 *
            10**AggregatorV3Interface(priceFeed).decimals()) /
            (uint256(getLatestPrice()) * collateralRatio);
        return min;
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
            state: LoanState.ACTIVE,
            liquidationId: 0
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
        loan.liquidationId = ILiquidator(liquidator).startLiquidation(
            loanId,
            loan.collateral,
            loan.amount,
            liquidationDuration
        );
    }

    function liquidated(uint256 loanId)
        external
        isInCorrectState(loanId, LoanState.UNDER_LIQUIDATION)
    {
        Loan storage loan = loans[loanId];
        (uint256 collateral, address buyer) = ILiquidator(liquidator)
            .stopLiquidation(loan.liquidationId);
        loan.collateral -= collateral;
        loan.amount = 0;
        loan.state = LoanState.LIQUIDATED;
        payable(buyer).transfer(collateral);
    }

    function increaseCollateral(uint256 loanId)
        external
        payable
        isNotZero(msg.value)
        isInCorrectState(loanId, LoanState.ACTIVE)
    {
        loans[loanId].collateral += msg.value;
        emit CollateralIncreased(msg.sender, loanId, msg.value);
    }

    function decreaseCollateral(uint256 loanId, uint256 amount)
        external
        isNotZero(amount)
    {
        Loan storage loan = loans[loanId];
        require(msg.sender == loan.recipient, Error.ONLY_LOAN_OWNER);
        require(loan.state == LoanState.ACTIVE, Error.INVALID_LOAN_STATE);
        require(
            minCollateral(loan.amount) <= loan.collateral - amount,
            Error.INSUFFICIENT_COLLATERAL
        );
        loan.collateral -= amount;
        emit CollateralDecreased(msg.sender, loanId, amount);
        payable(loan.recipient).transfer(amount);
    }
}
