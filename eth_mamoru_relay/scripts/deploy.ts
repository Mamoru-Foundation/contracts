import { ethers } from "hardhat";

async function main() {
 // [deployer] = await ethers.getSigners();
  const RelayContract = await ethers.getContractFactory("EthMamoruRelay");
  const lock = await RelayContract.deploy();

  await lock.deployed();

  console.log(
    `RelayContract deployed to ${lock.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
