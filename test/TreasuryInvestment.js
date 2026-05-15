const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("UniFundTreasury Rule-Based Hedging", function () {
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

  it("Should propose a hedge correctly", async function () {
    const amount = ethers.parseEther("2");
    await treasury.proposeHedge(amount, true);
    const req = await treasury.hedgeRequests(1);
    expect(req.amount).to.equal(amount);
    expect(req.isHedge).to.be.true;
  });

  it("Should fail if exceeding max hedge ratio (80%)", async function () {
    const tooMuch = ethers.parseEther("4.5"); // 4.5 > 80% of 5 (which is 4)
    await expect(treasury.proposeHedge(tooMuch, true)).to.be.revertedWith("Exceeds max hedge ratio");
  });

  it("Should execute hedge after voting period", async function () {
    const amount = ethers.parseEther("1");
    await treasury.proposeHedge(amount, true);
    
    // Advance time
    for(let i=0; i<101; i++) await ethers.provider.send("evm_mine");

    await treasury.executeHedge(1);
    expect(await treasury.totalHedged()).to.equal(amount);
  });

  it("Should enforce cooldown rule", async function () {
    await treasury.proposeHedge(ethers.parseEther("1"), true);
    for(let i=0; i<101; i++) await ethers.provider.send("evm_mine");
    await treasury.executeHedge(1);

    await expect(treasury.proposeHedge(ethers.parseEther("1"), true)).to.be.revertedWith("Cooldown active");
  });
});
