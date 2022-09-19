const {
    time,
    loadFixture,
    mine
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { constants } = require("ethers");
const { ethers } = require("hardhat");

const priceFeedAddress = "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0";
const collateralRatio = BigInt(0.5e18);

const ZERO = constants.Zero;
const ONE = constants.One;

const INSUFFICIENT_COLLATERAL = "INSUFFICIENT_COLLATERAL";
const SUFFICIENT_COLLATERAL = "SUFFICIENT_COLLATERAL";
const INVALID_AMOUNT = "INVALID_AMOUNT";
const INVALID_LOAN_STATE = "INVALID_LOAN_STATE";

const LoanState = {
    UNDEFINED: 0,
    ACTIVE: 1,
    UNDER_LIQUIDATION: 2,
    LIQUIDATED: 3,
    SETTLED: 4
}

const getBalance = ethers.provider.getBalance

async function deploy() {
    // Contracts are deployed using the first signer/account by default
    const [owner, jack] = await ethers.getSigners();

    const Dollar = await ethers.getContractFactory("Dollar");
    const dollar = await Dollar.deploy();

    const Bank = await ethers.getContractFactory("Bank");
    const bank = await Bank.deploy(dollar.address, priceFeedAddress, collateralRatio);

    const Liquidator = await ethers.getContractFactory("Liquidator");
    const liquidator = await Liquidator.deploy(bank.address, dollar.address);

    const price = await bank.getLatestPrice();
    const factor = BigInt(0.5e18);
    const scale = BigInt(1e18);
    const TestPriceFeed = await ethers.getContractFactory("PriceFeed");
    const testPriceFeed = await TestPriceFeed.deploy(price.mul(factor).div(scale));

    await bank.setLiquidator(liquidator.address);
    await dollar.grantRole(await dollar.MINTER_ROLE(), bank.address);
    await dollar.grantRole(await dollar.MINTER_ROLE(), owner.address);
    await dollar.mint(owner.address, BigInt(1e36));
    await dollar.approve(liquidator.address, BigInt(1e36));

    return { bank, dollar, liquidator, testPriceFeed, owner, jack };
}

async function takeOutLoan() {
    const { bank, dollar, liquidator, testPriceFeed, owner, jack } = await deploy();

    const amount = BigInt(10e18);
    const collateral = await bank.minCollateral(amount);

    await bank.connect(jack).takeOutLoan(amount, { value: collateral });
    const loanId = await bank.lastLoanId();

    return { bank, dollar, liquidator, testPriceFeed, owner, jack, loanId }
}

async function liquidate() {
    const { bank, dollar, liquidator, testPriceFeed, owner, jack, loanId } = await takeOutLoan();
    await bank.setPriceFeed(testPriceFeed.address);
    await bank.liquidate(loanId);
    return { bank, dollar, liquidator, owner, jack, loanId };
}

describe("Bank", function () {
    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.

    describe("TakeOut Loan", function () {
        it("Should recieve loan", async function () {
            const { bank, dollar, jack } = await loadFixture(deploy);

            const amount = BigInt(10e18);
            const collateral = await bank.minCollateral(amount);
            const balanceBeforeLoan = await dollar.balanceOf(jack.address);

            await bank.connect(jack).takeOutLoan(amount, { value: collateral });

            const balanceAfterLoan = await dollar.balanceOf(jack.address);

            expect(balanceAfterLoan.sub(balanceBeforeLoan)).to.equal(amount);

            const loanId = await bank.lastLoanId();
            const loan = await bank.loans(loanId);

            expect(loan.recipient).to.equal(jack.address);
            expect(loan.collateral).to.equal(collateral);
            expect(loan.amount).to.equal(amount);
            expect(loan.state).to.equal(1);
        });

        it("Should fail because of insuficient collateral", async function () {
            const { bank, jack } = await loadFixture(deploy);

            const factor = BigInt(0.5e18);
            const amount = BigInt(10e18);
            const collateral = (await bank.minCollateral(amount)).mul(factor).div(BigInt(1e18));

            await expect(bank.connect(jack).takeOutLoan(amount, { value: collateral })).to.be.revertedWith(INSUFFICIENT_COLLATERAL);
        });

        it("Should fail because of zero amount", async function () {

            const { bank, jack } = await loadFixture(deploy);

            await expect(bank.connect(jack).takeOutLoan(ZERO, { value: ONE })).to.be.revertedWith(INVALID_AMOUNT);
            await expect(bank.connect(jack).takeOutLoan(ONE, { value: ZERO })).to.be.revertedWith(INVALID_AMOUNT);
        });
    });

    describe("Settle Loan", function () {
        it("Should settle part of loan and recieve collateral", async function () {
            const { bank, dollar, jack, loanId } = await loadFixture(takeOutLoan);

            const amount = BigInt(5e18);

            const activeLoan = await bank.loans(loanId);
            const balanceBeforeSettle = await dollar.balanceOf(jack.address);
            const ethBalanceBeforeSettle = await getBalance(activeLoan.recipient);

            await dollar.connect(jack).approve(bank.address, amount);
            await bank.connect(jack).settleLoan(loanId, amount);

            const settledLoan = await bank.loans(loanId);
            const balanceAfterSettle = await dollar.balanceOf(jack.address);
            const ethBalanceAfterSettle = await getBalance(activeLoan.recipient);
            const freeCollateral = activeLoan.collateral.mul(amount).div(activeLoan.amount);

            expect(balanceBeforeSettle.sub(balanceAfterSettle), "Amount hasn't been recieved").to.equal(amount);
            expect(ethBalanceAfterSettle.sub(ethBalanceBeforeSettle), "Collateral hasn't been paid").to.gt(0);
            expect(settledLoan.collateral).to.equal(activeLoan.collateral.sub(freeCollateral));
            expect(settledLoan.amount).to.equal(activeLoan.amount.sub(amount));
            expect(settledLoan.state).to.equal(LoanState.ACTIVE);
        });

        it("Should fail because of zero amount", async function () {

            const { bank, jack, loanId } = await loadFixture(takeOutLoan);

            await expect(bank.connect(jack).settleLoan(loanId, ZERO)).to.be.revertedWith(INVALID_AMOUNT);
        });

        it("Should fail because of not active loan state", async function () {

            const { bank, jack } = await loadFixture(takeOutLoan);

            await expect(bank.connect(jack).settleLoan(0, ONE)).to.be.revertedWith(INVALID_LOAN_STATE);
        });
    });

    describe("Liquidate", function () {
        it("Should fail because of sufficient collateral", async function () {
            const { bank, loanId } = await loadFixture(takeOutLoan);

            await expect(bank.liquidate(loanId)).to.be.rejectedWith(SUFFICIENT_COLLATERAL);
        });

        it("Should start liquidation and change loan state", async function () {
            const { bank, testPriceFeed, loanId } = await loadFixture(takeOutLoan);

            await bank.setPriceFeed(testPriceFeed.address);
            await bank.liquidate(loanId);

            const loan = await bank.loans(loanId);

            expect(loan.state).to.equal(LoanState.UNDER_LIQUIDATION);
        });

        it("Should fail because of not active loan state", async function () {
            const { bank, jack } = await loadFixture(takeOutLoan);

            expect(bank.connect(jack).settleLoan(ZERO, ONE)).to.be.revertedWith(INVALID_LOAN_STATE);
        });
    });

    describe("Liquidated", function () {
        it("Should fail because of not under liquidation loan state", async function () {
            const { bank } = await loadFixture(liquidate);

            await expect(bank.liquidated(ZERO)).to.be.rejectedWith(INVALID_LOAN_STATE);
        });

        it("Should liquidated and send collateral to buyer", async function () {
            const { bank, liquidator, loanId, owner } = await loadFixture(liquidate);
            const ethBalanceBeforeLiquidation = await getBalance(owner.address);
            const { collateral, liquidationId } = await bank.loans(loanId);
            await liquidator.placeBid(liquidationId, collateral);
            const duration = await bank.liquidationDuration();
            await mine(duration);

            await bank.liquidated(loanId);

            const ethBalanceAfterLiquidation = await getBalance(owner.address);
            const balanceChange = ethBalanceAfterLiquidation.sub(ethBalanceBeforeLiquidation);
            const liquidatedLoan = await bank.loans(loanId);
            const bidCollateral = (await liquidator.liquidations(liquidatedLoan.liquidationId)).collateral;

            expect(liquidatedLoan.amount).to.equal(ZERO);
            expect(liquidatedLoan.state).to.equal(LoanState.LIQUIDATED);
            expect(balanceChange).to.lte(bidCollateral);
            expect(balanceChange).to.gt(BigInt(0));
        });
    });
});

module.exports = {
    deploy,
    takeOutLoan,
    liquidate,
    ZERO,
    ONE
}
