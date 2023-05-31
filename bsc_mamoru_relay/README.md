# Bsc Incident Relay Contracts
This repository contains the source code for the Bsc Incident Relay contracts.

The Bsc Incident Relay contract is a contract that stores the incidents from the Validation Chain in Bsc.

This contract is based on the [OpenZeppelin](https://openzeppelin.com/) framework. 


Try running some of the following tasks:

```shell
cd bsc_mamoru_relay
npm i @openzeppelin/contracts 
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
npx hardhat export-abi 
abigen  --abi=abi/contracts/BscMamoruRelay.sol/BscMamoruRelay.json --pkg=incident_relay --out=contracts/BscMamoruRelay.go
```
