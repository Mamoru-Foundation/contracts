import {HardhatUserConfig, task, types} from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-solhint";
import "hardhat-abi-exporter";

// Show the balance of an account
task("balance", "Prints an account's balance")
    .addParam("account", "The account's address", null, types.string)
    .setAction(async (taskArgs: { account: string; }) => {
      const balance = await ethers.provider.getBalance(taskArgs.account);
      console.log(ethers.utils.formatEther(balance), "ETH");
});

// Show the list of accounts
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// Show the list of accounts
task("register_validator", "Register validator account")
    .addParam("account", "The account's address", null, types.string)
    .addParam("contract", "The contract's address", null, types.string)
    .setAction(async (taskArgs: { account: string; contract: string; }) => {
        const EthRelay = await ethers.getContractFactory("EthMamoruRelay")
        const contract = await EthRelay.attach(taskArgs.contract)
        await contract.addValidator(taskArgs.account)
        console.log("Validator registered")
});


// Private key for the account to use for deployment (must be funded)
//0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 it's test private key
const PRIVATE_KEY: string = (process.env.PRIVATE_KEY as string) ?? "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

const config: HardhatUserConfig = {
  solidity: {
    version:"0.8.18",
    settings:{
        optimizer: {
            enabled: true,
            runs: 200
        }
    }
  },
  //defaultNetwork: "localhost",
  networks: {
    hardhat: {
    },
    sepolia: {
      url: `https://sepolia.infura.io/v3/181b5fd5f80745f1bb5993c87966ece4`,
      accounts: [PRIVATE_KEY]
    },
    bsc_testnet: {
      url: `https://data-seed-prebsc-1-s1.binance.org:8545`,
      chainId: 97,
      gasPrice: 20000000000,
      accounts: [PRIVATE_KEY]
    },
    bsc_mainnet: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      gasPrice: 20000000000,
      accounts: [PRIVATE_KEY]
    },
    eth_testnet: {
      url: "https://endpoints.omniatech.io/v1/eth/goerli/public",
      chainId: 5,
      gasPrice: 20000000000,
      accounts: [PRIVATE_KEY]
    },
    eth_mainnet: {
      url: "https://ethereum.publicnode.com",
      chainId: 1,
      gasPrice: 20000000000,
      accounts: [PRIVATE_KEY]
    }
  }
};

export default config;
