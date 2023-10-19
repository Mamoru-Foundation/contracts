// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract Relay is Ownable {
    using MessageHashUtils for bytes32;
    using ECDSA for bytes32;

    mapping(address => bool) private validators;
    uint256 private validatorCount = 0;
    mapping(bytes32 => bool) private relayedTxs;

    constructor() Ownable(msg.sender) {}

    function addValidator(address _validator) public onlyOwner {
        if (!validators[_validator]) {
            validators[_validator] = true;
            validatorCount++;
        }
    }

    function removeValidator(address _validator) public onlyOwner {
        if (validators[_validator]) {
            validators[_validator] = false;
            validatorCount--;
        }
    }

    function getBFTThreshold() public view returns (uint256) {
        return (validatorCount * 2 / 3) + 1;  // (2/3)+1 BFT
    }

    function relayTransaction(
        address target,
        bytes memory data,
        uint256 expiration,
        bytes[] memory signatures
    ) public {
        require(expiration > block.timestamp, "Transaction expired");

        bytes32 txHash = keccak256(abi.encode(target, data, expiration));
        require(!relayedTxs[txHash], "Transaction already processed");

        bytes32 messageHash = txHash.toEthSignedMessageHash();

        address[] memory seenSigners = new address[](signatures.length);
        uint256 seenCount = 0;
        uint256 validSignatures = 0;
        for (uint256 i = 0; i < signatures.length; i++) {
            address signer = messageHash.recover(signatures[i]);

            // Solidity does not support local memory mappings
            // So, iterating to check signer uniqness
            for (uint256 j = 0; j < seenCount; j++) {
                require(signer != seenSigners[j], "Signatures must be from different validators");
            }
            seenSigners[seenCount] = signer;
            seenCount++;

            if (validators[signer]) {
                validSignatures++;
            }
        }
        require(validSignatures >= getBFTThreshold(), "Insufficient valid signatures");

        (bool success,) = target.call(data);
        require(success, "Can't call target contract, check target and data");

        relayedTxs[txHash] = true;
    }
}
