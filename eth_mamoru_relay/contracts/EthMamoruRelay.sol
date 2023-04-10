// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract EthMamoruRelay is Ownable {

    uint public incidentCount = 0;

    struct Incident {
        // define properties for an Incident
        string Id;
        address Address;
        bytes Data;
        uint64 CreatedAt;
    }

    struct Daemon {
        // define properties for a Daemon
        string Id;
    }

    mapping(uint256 => Daemon)  daemons;
    mapping(string => mapping(uint256=>Incident))  daemonIncidents;
    mapping(address => bool)  validators;

    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event IncidentReported(string indexed daemonId, string indexed incidentId);

    function addValidator(address validator) public onlyOwner {
        validators[validator] = true;
        emit ValidatorAdded(validator);
        console.log("Validator added: %s", validator);
    }

    function removeValidator(address validator) public onlyOwner {
        validators[validator] = false;
        emit ValidatorRemoved(validator);
        console.log("Validator removed: %s", validator);
    }

    function addIncident(string memory daemonId, Incident memory _incident) public {
        console.log("Check validator address: %s", msg.sender);
        require(validators[msg.sender], "Only validators can report incidents.");
        // add the incident to the registry
        daemonIncidents[daemonId][incidentCount] = _incident;

        emit IncidentReported(daemonId, _incident.Id);
        incidentCount++;
        console.log("Incident reported: daemonId=%s, incidentId=%d count=%d", daemonId, _incident.Id, incidentCount);
    }

    function getIncidentsSinceByDaemon(string memory daemonId, uint64 sinceTimestamp) public view returns (Incident[] memory, uint256) {
        // return a list of incidents for the given daemon since the given timestamp
        uint256 count = 0;
        for (uint256 i = 0; i < incidentCount; i++) {
            if (daemonIncidents[daemonId][i].CreatedAt >= sinceTimestamp) {
                count++;
            }
        }
        Incident[] memory incidents = new Incident[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < incidentCount; i++) {
            if (daemonIncidents[daemonId][i].CreatedAt >= sinceTimestamp) {
                incidents[index] = daemonIncidents[daemonId][i];
                index++;
            }
        }
        console.log("Incidents since %s: %d", sinceTimestamp, count);
        return (incidents, count);
    }

    function hasIncidents(string memory daemonId, uint256 sinceTimestamp) public view returns (bool) {
        // return true if the given daemon has any incidents since the given timestamp
        for (uint256 i = 0; i < incidentCount; i++) {
            if (daemonIncidents[daemonId][i].CreatedAt >= sinceTimestamp) {
                console.log("Incident found: daemonId=%s, count=%d", daemonId, i);
                return true;
            }
        }
        return false;
    }
}

