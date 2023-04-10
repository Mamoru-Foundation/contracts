import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";


describe("EthMamoruRelay", function () {

  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployOneYearLockFixture() {

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const RelayContract = await ethers.getContractFactory("EthMamoruRelay");
    const relay = await RelayContract.deploy();

    return { relay, owner, otherAccount };
  }

  describe("Deployment", function () {
    const timestamp = Math.floor(Date.now() / 1000);

    // it("Should set the right incidentCount", async function () {
    //   const { relay } = await loadFixture(deployOneYearLockFixture);
    //
    //   expect(await relay.incidentCount()).to.equal(0);
    // });

    it("Should set the right owner", async function () {
      const { relay, owner } = await loadFixture(deployOneYearLockFixture);

      expect(await relay.owner()).to.equal(owner.address);
    });

    it("Should add the validator and emit an event", async function () {
      const { relay, otherAccount } = await loadFixture(
          deployOneYearLockFixture
      );

      await expect(relay.addValidator(otherAccount.address)).to
          .emit(relay, "ValidatorAdded").withArgs(otherAccount.address);
    });

    it("Should remove the validator and emit an event", async function () {
      const { relay, otherAccount } = await loadFixture(
          deployOneYearLockFixture
      );
      await relay.addValidator(otherAccount.address);
      await expect(relay.removeValidator(otherAccount.address)).to
          .emit(relay, "ValidatorRemoved").withArgs(otherAccount.address);
    });

    it("should allow validators to report incidents", async function () {
      // Deploy a mock validator
      const { relay, otherAccount} = await loadFixture(
          deployOneYearLockFixture
      );
       const [not_validator] = await ethers.getSigners();

        // Add the validator
      await expect(relay.addValidator(otherAccount.address)).to
          .emit(relay, "ValidatorAdded").withArgs(otherAccount.address);

      // Define a test incident
      const incident = {
        Id: "1",
        Address: otherAccount.address,
        Data: "0x0000000000000000000000000000000000000000",
        CreatedAt: timestamp,
      };

      // Call the addIncident function
      const daemonId = "test-daemon";

      await expect(relay.connect(not_validator).addIncident(daemonId, incident)).to.be
          .revertedWith("Only validators can report incidents.");

      await expect(await relay.connect(otherAccount).addIncident(daemonId, incident)).to
          .emit(relay, "IncidentReported").withArgs(daemonId, incident.Id);

      // Check that the incident count was incremented
      // const incidentCount = await relay.incidentCount();
      // expect(incidentCount.toNumber()).to.equal(1);

      // Check that the incident was added to the registry
      const [storedIncidents, count] = await relay.getIncidentsSinceByDaemon(daemonId, incident.CreatedAt);

      expect(count.toNumber()).to.equal(1);
      expect(storedIncidents).to.have.lengthOf(1);

      expect(storedIncidents[0].Id).to.equal(incident.Id);
      expect(storedIncidents[0].Address).to.equal(incident.Address);
      expect(storedIncidents[0].Data).to.equal(incident.Data);
      expect(storedIncidents[0].CreatedAt).to.equal(incident.CreatedAt);
    });

    it("should not allow non-validators to report incidents", async function () {
      // Deploy a mock validator
      const { relay} = await loadFixture(
          deployOneYearLockFixture
      );
      const [nonValidator] = await ethers.getSigners();

      // Define a test incident
      const incident = {
        Id: "1",
        Address: nonValidator.address,
        Data: "0x0000000000000000000000000000000000000000",
        CreatedAt: 1623469105
      };

      // Call the addIncident function as a non-validator
      const daemonId = "test-daemon";
      await expect(relay.connect(nonValidator).addIncident(daemonId, incident)).to.be
          .revertedWith("Only validators can report incidents.");
    });

  });

  describe("getIncidentsSinceByDaemon", () => {
    const daemonId = "testDaemon";
    const timestamp = Math.floor(Date.now() / 1000);

    it("should return empty array when no incidents reported", async () => {
      // Deploy a mock validator
      const { relay} = await loadFixture(
          deployOneYearLockFixture
      );
      const [incidents, count] = await relay.getIncidentsSinceByDaemon(daemonId, timestamp);
      expect(count).to.equal(0);
      expect(incidents).to.have.lengthOf(0);
    });

    it("should return array of incidents reported by a daemon since the timestamp", async () => {
      // Deploy a mock validator
      const { relay, owner} = await loadFixture(
          deployOneYearLockFixture
      );
      await relay.addValidator(owner.address)

      const incident1 = {Id: "incident1", Address: owner.address, Data: "0x0000000000000000000000000000000000000001", CreatedAt: timestamp - 100};
      const incident2 = {Id: "incident2", Address: owner.address, Data: "0x0000000000000000000000000000000000000002", CreatedAt: timestamp + 50};
      const incident3 = {Id: "incident3", Address: owner.address, Data: "0x0000000000000000000000000000000000000003", CreatedAt: timestamp + 10};

      await relay.addIncident(daemonId, incident1);
      await relay.addIncident(daemonId, incident2);
      await relay.addIncident(daemonId, incident3);

      const [incidents, count] = await relay.getIncidentsSinceByDaemon(daemonId, timestamp);

      expect(2).to.equal(count.toNumber());
      expect(incidents).to.have.lengthOf(2);

      expect(incidents[1].Id).to.deep.equal(incident2.Id);
      expect(incidents[1].Address).to.deep.equal(incident2.Address);
      expect(incidents[1].Data).to.deep.equal(incident2.Data);
      expect(incidents[1].CreatedAt.toNumber()).to.deep.equal(incident2.CreatedAt);

      expect(incidents[0].Id).to.deep.equal(incident3.Id);
      expect(incidents[0].Address).to.deep.equal(incident3.Address);
      expect(incidents[0].Data).to.deep.equal(incident3.Data);
      expect(incidents[0].CreatedAt.toNumber()).to.deep.equal(incident3.CreatedAt);
    });

    it("should not include incidents reported by other daemons", async () => {
      // Deploy a mock validator
      const { relay, owner} = await loadFixture(
          deployOneYearLockFixture
      );
      await relay.addValidator(owner.address)

      const incident1 = {Id: "incident1", Address: owner.address, Data: "0x0000000000000000000000000000000000000000", CreatedAt: timestamp + 10};
      const incident2 = {Id: "incident2", Address: owner.address, Data: "0x0000000000000000000000000000000000000000", CreatedAt: timestamp + 50};
      const incident3 = {Id: "incident3", Address: owner.address, Data: "0x0000000000000000000000000000000000000000", CreatedAt: timestamp + 100};

      await relay.addIncident(daemonId, incident1);
      await relay.addIncident("otherDaemon", incident2);
      await relay.addIncident(daemonId, incident3);

      const [incidents, count] = await relay.getIncidentsSinceByDaemon(daemonId, timestamp);

      expect(count.toNumber()).to.equal(2);
      expect(incidents).to.have.lengthOf(2);

      expect(incidents[0].Id).to.equal(incident3.Id);
      expect(incidents[0].Address).to.equal(incident3.Address);
      expect(incidents[0].Data).to.equal(incident3.Data);
      expect(incidents[0].CreatedAt.toNumber()).to.equal(incident3.CreatedAt);

      expect(incidents[1].Id).to.equal(incident1.Id);
      expect(incidents[1].Address).to.equal(incident1.Address);
      expect(incidents[1].Data).to.equal(incident1.Data);
      expect(incidents[1].CreatedAt.toNumber()).to.equal(incident1.CreatedAt);
    });

  });

});
