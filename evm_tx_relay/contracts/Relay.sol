// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract Relay is Ownable {
    using MessageHashUtils for bytes32;
    using ECDSA for bytes32;

    mapping(address => bool) private relayAddresses;
    uint256 private relayAddressCount = 0;
    mapping(bytes32 => bool) private relayedTxs;

    constructor() Ownable(msg.sender) {}

    function addRelayAddress(address _relayAddress) public onlyOwner {
        if (!relayAddresses[_relayAddress]) {
            relayAddresses[_relayAddress] = true;
            relayAddressCount++;
        }
    }

    function removeRelayAddress(address _relayAddress) public onlyOwner {
        if (relayAddresses[_relayAddress]) {
            relayAddresses[_relayAddress] = false;
            relayAddressCount--;
        }
    }

    function getBFTThreshold() public view returns (uint256) {
        return (relayAddressCount * 2 / 3) + 1;  // (2/3)+1 BFT
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
        uint256 validSignatures = 0;
        for (uint256 i = 0; i < signatures.length; i++) {
            address signer = messageHash.recover(signatures[i]);

            if (relayAddresses[signer]) {
                validSignatures++;
            }
        }
        require(validSignatures >= getBFTThreshold(), "Insufficient valid signatures");

        (bool success,) = target.call(data);
        require(success, "Can't call target contract, check target and data");

        relayedTxs[txHash] = true;
    }
}
