const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { deploy, takeOutLoan, liquidate, ZERO } = require("./Bank");

const ONLY_BANK = "ONLY_BANK";

const LiquidationState = {
    ACTIVE: 0,
    FINISHED: 1
}

describe("Liquidator", function () {
    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    describe("Deployment", function () {
        it("Always Fail", async function () {
            expect(true).to.equal(false);
        });
    });

    describe("Start Liquidation", function () {
        it("Should fail because of being called by an address which is not Bank", async function () {
            const { liquidator } = await loadFixture(deploy);
            await expect(liquidator.startLiquidation(ZERO, ZERO, ZERO, ZERO)).to.be.rejectedWith(ONLY_BANK);
        });

        it("Should start liquidation", async function () {
            const { bank, liquidator, loanId } = await loadFixture(liquidate);
            const lastLiquidationId = await liquidator.lastLiquidationId;
            const lastLiquidation = await liquidator.liquidations(lastLiquidationId);
            const loan = await bank.loans(loanId);
            expect(lastLiquidation.loanId).to.equal(loanId);
            expect(lastLiquidation.collateral).to.equal(loan.collateral);
            expect(lastLiquidation.amount).to.equal(loan.amont);
            expect(lastLiquidation.state).to.equal(LiquidationState.ACTIVE);
        });
    });
});
