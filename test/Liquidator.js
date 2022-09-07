const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("Liquidator", function () {
    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    async function deploy() {

        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();

        const Liquidator = await ethers.getContractFactory("Liquidator");
        const liquidator = await Liquidator.deploy();

        return { liquidator, owner, otherAccount };
    }

    describe("Deployment", function () {
        it("Always Fail", async function () {
            expect(true).to.equal(false);
        });
    });
});
