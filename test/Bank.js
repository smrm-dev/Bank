const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { constants } = require("ethers");
const ZERO = constants.Zero;
const ONE = constants.One;

const INSUFFICIENT_COLLATERAL = "INSUFFICIENT_COLLATERAL";
const INVALID_AMOUNT = "INVALID_AMOUNT";

describe("Bank", function () {
    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    async function deploy() {

        // Contracts are deployed using the first signer/account by default
        const [owner, jack] = await ethers.getSigners();

        const Dollar = await ethers.getContractFactory("Dollar");
        const dollar = await Dollar.deploy();

        const Bank = await ethers.getContractFactory("Bank");
        const bank = await Bank.deploy(dollar.address);

        await dollar.grantRole(await dollar.MINTER_ROLE(), bank.address);

        return { bank, dollar, owner, jack };
    }

    describe("Deployment", function () {
        it("Always Fail", async function () {
            expect(true).to.equal(false);
        });
    });

    describe("TakeOut Loan", function () {
        it("Should recieve loan", async function () {
            const { bank, dollar, jack } = await loadFixture(deploy);

            const collateral = BigInt(1000e18);
            const amount = BigInt(1000e18);
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

            const collateral = BigInt(1e18);
            const amount = BigInt(1000e18);

            await expect(bank.connect(jack).takeOutLoan(amount, { value: collateral })).to.be.revertedWith(INSUFFICIENT_COLLATERAL);
        });

        it("Should fail because of zero amount", async function () {

            const { bank, jack } = await loadFixture(deploy);

            await expect(bank.connect(jack).takeOutLoan(ZERO, { value: ONE })).to.be.revertedWith(INVALID_AMOUNT);
            await expect(bank.connect(jack).takeOutLoan(ONE, { value: ZERO })).to.be.revertedWith(INVALID_AMOUNT);
        });
    });
});
