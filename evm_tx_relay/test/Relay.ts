import {loadFixture} from "@nomicfoundation/hardhat-network-helpers";
import {expect} from "chai";
import {ethers} from "hardhat";

describe("Relay and TestTarget", function () {
    async function deployContracts() {
        const [owner, relayAddress1, relayAddress2, otherAccount] = await ethers.getSigners();

        const Relay = await ethers.getContractFactory("Relay");
        const relay = await Relay.deploy({from: owner});

        await relay.addRelayAddress(relayAddress1.address);
        await relay.addRelayAddress(relayAddress2.address);

        const TestTarget = await ethers.getContractFactory("TestTarget");
        const testTarget = await TestTarget.deploy({from: owner});

        return {relay, testTarget, owner, relayAddress1, relayAddress2, otherAccount};
    }

    describe("Deployment and Configuration", function () {
        it("Should set the right owner", async function () {
            const {relay, owner} = await loadFixture(deployContracts);
            expect(await relay.owner()).to.equal(owner.address);
        });

        it("Should have valid BFT threshold", async function () {
            const {relay} = await loadFixture(deployContracts);

            const threshold = await relay.getBFTThreshold();

            // Since we have 2 relay addresses, the threshold should be 2
            expect(threshold).to.equal(2);
        });
    });

    describe("Relay Transactions", function () {
        // Since relayAddresses mapping is private, we'll use indirect methods to test.
        it("Should relay transaction", async function () {
            const {relay, testTarget, relayAddress1, relayAddress2} = await loadFixture(deployContracts);

            const data = testTarget.interface.encodeFunctionData("testFunction", [ethers.encodeBytes32String("Test Data")]);
            const expiration = (await ethers.provider.getBlock('latest')).timestamp + 120;

            // Sign the transaction with both relay addresses
            const messageHash = ethers.keccak256(
                ethers.AbiCoder.defaultAbiCoder().encode(
                    ['address', 'bytes', 'uint256'],
                    [await testTarget.getAddress(), data, expiration],
                )
            );

            const signature1 = await relayAddress1.signMessage(ethers.getBytes(messageHash));
            const signature2 = await relayAddress2.signMessage(ethers.getBytes(messageHash));

            // Send the transaction
            const tx = await relay.relayTransaction(
                await testTarget.getAddress(),
                data,
                expiration,
                [signature1, signature2],
            );
            await tx.wait();

            // Check if the transaction affected the target contract
            expect(await testTarget.lastData()).to.equal(ethers.encodeBytes32String("Test Data"));
        });

        it("Should reject relay transaction with insufficient signatures", async function () {
            const {relay, testTarget, relayAddress1, relayAddress2} = await loadFixture(deployContracts);

            const data = testTarget.interface.encodeFunctionData("testFunction", [ethers.encodeBytes32String("Test Data")]);
            const expiration = (await ethers.provider.getBlock('latest')).timestamp + 120;

            const messageHash = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'bytes', 'uint256'], [await testTarget.getAddress(), data, expiration]));

            const signature1 = await relayAddress1.signMessage(ethers.getBytes(messageHash));

            const relayResult = relay.relayTransaction(
                await testTarget.getAddress(), data, expiration, [signature1],
            );

            await expect(relayResult).to.be.revertedWith("Insufficient valid signatures");
        });

        it("Fails if the transaction is expired", async function () {
            const {relay, testTarget, relayAddress1, relayAddress2} = await loadFixture(deployContracts);

            const data = testTarget.interface.encodeFunctionData("testFunction", [ethers.encodeBytes32String("Test Data")]);
            const expiration = (await ethers.provider.getBlock('latest')).timestamp - 1;

            const messageHash = ethers.keccak256(
                ethers.AbiCoder.defaultAbiCoder().encode(
                    ['address', 'bytes', 'uint256'],
                    [await testTarget.getAddress(), data, expiration],
                ),
            );
            const signature1 = await relayAddress1.signMessage(ethers.getBytes(messageHash));
            const signature2 = await relayAddress2.signMessage(ethers.getBytes(messageHash));

            const relayRequest = relay.relayTransaction(
                await testTarget.getAddress(), data, expiration, [signature1, signature2],
            );

            await expect(relayRequest).to.be.revertedWith("Transaction expired");
        });

        it("Fails if the transaction is already relayed", async function () {
            const {relay, testTarget, relayAddress1, relayAddress2} = await loadFixture(deployContracts);

            const data = testTarget.interface.encodeFunctionData("testFunction", [ethers.encodeBytes32String("Test Data")]);
            const expiration = (await ethers.provider.getBlock('latest')).timestamp + 120;

            const messageHash = ethers.keccak256(
                ethers.AbiCoder.defaultAbiCoder().encode(
                    ['address', 'bytes', 'uint256'],
                    [await testTarget.getAddress(), data, expiration],
                ),
            );
            const signature1 = await relayAddress1.signMessage(ethers.getBytes(messageHash));
            const signature2 = await relayAddress2.signMessage(ethers.getBytes(messageHash));

            await relay.relayTransaction(
                await testTarget.getAddress(), data, expiration, [signature1, signature2],
            );

            const relayRequest2 = relay.relayTransaction(
                await testTarget.getAddress(), data, expiration, [signature1, signature2],
            );

            await expect(relayRequest2).to.be.revertedWith("Transaction already processed");
        });
    });
});
