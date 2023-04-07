import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-solhint";
import "hardhat-abi-exporter";

const config: HardhatUserConfig = {
  solidity: "0.8.18",
};

export default config;
