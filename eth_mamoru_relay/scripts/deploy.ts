import { ethers } from "hardhat";

async function main() {
  const RelayContract = await ethers.getContractFactory("EthMamoruRelay");
  const relay = await RelayContract.deploy();
  await relay.deployed();

  console.log(
    `${relay.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
