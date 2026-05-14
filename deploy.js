const { ethers } = require("hardhat");

async function main() {
  const [deployer, committee2, committee3] = await ethers.getSigners();

  const societyName = "UniFund FITE2010 Society";
  const committee = [committee2.address, committee3.address]; // deployer is auto-added by constructor
  const membershipFee = ethers.parseEther("0.01");
  const membershipDuration = 365 * 24 * 60 * 60; // 1 year
  const votingPeriodBlocks = 20; // short for demo; increase for production/testnet

  const UniFundTreasury = await ethers.getContractFactory("UniFundTreasury");
  const treasury = await UniFundTreasury.deploy(
    societyName,
    committee,
    membershipFee,
    membershipDuration,
    votingPeriodBlocks,
    { gasLimit: 15000000 }
  );

  await treasury.waitForDeployment();
  const address = await treasury.getAddress();

  console.log("UniFundTreasury deployed to:", address);
  console.log("Society:", societyName);
  console.log("Deployer / first committee:", deployer.address);
  console.log("Other committee:", committee);
  console.log("Membership fee:", ethers.formatEther(membershipFee), "ETH");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
