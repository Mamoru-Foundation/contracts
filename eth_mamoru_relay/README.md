# Ethereum Incident Relay Contracts
This repository contains the source code for the Ethereum Incident Relay contracts.

The Ethereum Incident Relay contract is a contract that stores the incidents from the Validation Chain in Ethereum.

This contract is based on the [OpenZeppelin](https://openzeppelin.com/) framework. 


Try running some of the following tasks:

```shell
cd eth_mamoru_relay
npm i @openzeppelin/contracts 
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
npx hardhat export-abi 
abigen  --abi=abi/contracts/EthMamoruRelay.sol/EthMamoruRelay.json --pkg=incident_relay --out=contracts/BscMamoruRelay.go
```
