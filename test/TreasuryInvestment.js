const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("UniFundTreasury Investment Features", function () {
  let treasury;
  let owner, committee1, student, strategy;
  const membershipFee = ethers.parseEther("0.1");
  const membershipDuration = 1000;
  const votingPeriod = 100;

  beforeEach(async function () {
    [owner, committee1, student, strategy] = await ethers.getSigners();

    const UniFundTreasury = await ethers.getContractFactory("UniFundTreasury");
    treasury = await UniFundTreasury.deploy(
      "Test Society",
      [committee1.address],
      membershipFee,
      membershipDuration,
      votingPeriod
    );
  });

  describe("Reserve Ratio and Strategy Setup", function () {
    it("Should have default reserve ratio of 20%", async function () {
      expect(await treasury.reserveRatioBps()).to.equal(2000);
    });

    it("Should allow committee to set reserve ratio", async function () {
      await treasury.setReserveRatio(3000);
      expect(await treasury.reserveRatioBps()).to.equal(3000);
    });

    it("Should allow committee to set investment strategy", async function () {
      await treasury.setInvestmentStrategy(strategy.address);
      expect(await treasury.investmentStrategy()).to.equal(strategy.address);
    });

    it("Should not allow non-committee to set ratio", async function () {
      await expect(treasury.connect(student).setReserveRatio(3000)).to.be.revertedWith("Only committee");
    });
  });

  describe("Investment Allocation", function () {
    beforeEach(async function () {
      // Add funds to treasury
      await owner.sendTransaction({
        to: await treasury.getAddress(),
        value: ethers.parseEther("10")
      });
      await treasury.setInvestmentStrategy(strategy.address);
    });

    it("Should calculate idle funds correctly (20% reserve of 10 ETH = 2 ETH reserve, 8 ETH idle)", async function () {
      const idle = await treasury.getIdleFunds();
      expect(idle).to.equal(ethers.parseEther("8"));
    });

    it("Should allocate idle funds to strategy", async function () {
      const amount = ethers.parseEther("5");
      const initialStrategyBalance = await ethers.provider.getBalance(strategy.address);
      
      await treasury.allocateIdleFunds(amount);
      
      expect(await treasury.totalInvested()).to.equal(amount);
      expect(await ethers.provider.getBalance(strategy.address)).to.equal(initialStrategyBalance + amount);
      expect(await treasury.getLiquidBalance()).to.equal(ethers.parseEther("5"));
      expect(await treasury.treasuryBalance()).to.equal(ethers.parseEther("10"));
    });

    it("Should fail if allocating more than idle funds", async function () {
      const tooMuch = ethers.parseEther("9"); // Only 8 is idle
      await expect(treasury.allocateIdleFunds(tooMuch)).to.be.revertedWith("Amount exceeds idle funds");
    });
  });

  describe("Divestment", function () {
    beforeEach(async function () {
      await owner.sendTransaction({
        to: await treasury.getAddress(),
        value: ethers.parseEther("10")
      });
      await treasury.setInvestmentStrategy(strategy.address);
      await treasury.allocateIdleFunds(ethers.parseEther("5"));
    });

    it("Should update accounting on divestment", async function () {
      await treasury.divestFunds(ethers.parseEther("2"));
      expect(await treasury.totalInvested()).to.equal(ethers.parseEther("3"));
      // Note: In this demo, divestFunds only updates accounting as mock strategy 
      // is just an EOA. In real use, strategy would send ETH back.
    });

    it("Should fail if divesting more than invested", async function () {
      await expect(treasury.divestFunds(ethers.parseEther("6"))).to.be.revertedWith("Amount exceeds invested funds");
    });
  });
});
