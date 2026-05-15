const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("UniFundTreasury Quant Rebalancing", function () {
  let treasury;
  let owner, committee1, strategy;
  const membershipFee = ethers.parseEther("0.1");
  const membershipDuration = 1000;
  const votingPeriod = 100;

  beforeEach(async function () {
    [owner, committee1, strategy] = await ethers.getSigners();
    const UniFundTreasury = await ethers.getContractFactory("UniFundTreasury");
    treasury = await UniFundTreasury.deploy(
      "Test Society",
      [committee1.address],
      membershipFee,
      membershipDuration,
      votingPeriod
    );
    await owner.sendTransaction({
      to: await treasury.getAddress(),
      value: ethers.parseEther("10")
    });
    await treasury.setInvestmentStrategy(strategy.address);
    await treasury.allocateIdleFunds(ethers.parseEther("5"));
  });

  it("Should propose a rebalance correctly", async function () {
    const targetRatio = 5000; // 50%
    await treasury.proposeRebalance(targetRatio);
    const req = await treasury.hedgeRequests(1);
    expect(req.targetRatio).to.equal(targetRatio);
  });

  it("Should execute rebalance and shift funds proportionally", async function () {
    const targetRatio = 5000; // 50%
    await treasury.proposeRebalance(targetRatio);
    
    // Advance time
    for(let i=0; i<101; i++) await ethers.provider.send("evm_mine");

    await treasury.executeRebalance(1);
    
    // 50% of 5 ETH = 2.5 ETH
    expect(await treasury.totalHedged()).to.equal(ethers.parseEther("2.5"));
    expect(await treasury.totalInvested()).to.equal(ethers.parseEther("2.5"));
    expect(await treasury.targetHedgeRatioBps()).to.equal(targetRatio);
  });

  it("Should fail if exceeding max hedge ratio (80%)", async function () {
    await expect(treasury.proposeRebalance(8500)).to.be.revertedWith("Exceeds max hedge ratio");
  });
});
