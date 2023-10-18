import {HardhatUserConfig, task, types} from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

task("add-relay-address", "Register relay address")
    .addParam("relayAddress", "The relay address", null, types.string)
    .addParam("contract", "The contract's address", null, types.string)
    .setAction(async (taskArgs: { relayAddress: string; contract: string; }, runtime) => {
        const EthRelay = await runtime.ethers.getContractFactory("Relay");
        const contract = EthRelay.attach(taskArgs.contract);
        await contract.addRelayAddress(taskArgs.relayAddress);

        console.log("Ok");
    });

task("remove-relay-address", "Register relay address")
    .addParam("relayAddress", "The relay address", null, types.string)
    .addParam("contract", "The contract's address", null, types.string)
    .setAction(async (taskArgs: { relayAddress: string; contract: string; }, runtime) => {
        const EthRelay = await runtime.ethers.getContractFactory("Relay");
        const contract = EthRelay.attach(taskArgs.contract);
        await contract.removeRelayAddress(taskArgs.relayAddress);

        console.log("Ok");
    });

task("deploy", "Deploy the contract")
    .setAction(async (_, runtime) => {
        const relay = await runtime.ethers.deployContract("Relay");
        await relay.waitForDeployment();

        console.log(
            `Address: ${relay.target}`
        );
    });

const PRIVATE_KEY: string = process.env.HARDHAT_PRIVATE_KEY as string ?? '0x0000000000000000000000000000000000000000000000000000000000000000';

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.20",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200
            }
        }
    },
    networks: {
        hardhat: {},
        bsc_testnet: {
            url: `https://data-seed-prebsc-1-s1.binance.org:8545`,
            chainId: 97,
            accounts: [PRIVATE_KEY]
        },
        bsc_mainnet: {
            url: "https://bsc-dataseed.binance.org/",
            chainId: 56,
            accounts: [PRIVATE_KEY]
        },
        eth_sepolia: {
            url: `https://sepolia.infura.io/v3/181b5fd5f80745f1bb5993c87966ece4`,
            accounts: [PRIVATE_KEY]
        },
        eth_mainnet: {
            url: "https://ethereum.publicnode.com",
            chainId: 1,
            accounts: [PRIVATE_KEY]
        }
    }
};

export default config;
