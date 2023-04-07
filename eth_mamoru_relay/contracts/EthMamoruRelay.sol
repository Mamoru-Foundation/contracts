// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

//todo
//interface MamoruRelayInterface {
//    function addValidator(address _validator) public;
//    function removeValidator(address _validator) public;
//    function addIncident(uint256 _daemonId, uint256 _incidentId, Incident memory _incident) public;
//    function getIncidentsSinceByDaemon(uint256 _daemonId, uint256 _sinceTimestamp) public view returns (Incident[] memory);
//    function hasIncidents(uint256 _daemonId, uint256 _sinceTimestamp) public view returns (bool);
//}

contract EthMamoruRelay is Ownable {

    uint public incidentCount = 0;

    struct Incident {
        // define properties for an Incident
        uint256 Id;
        address Address;
        bytes[] Data;
        uint64 CreatedAt;
        address ReportedBy;
    }

    struct Daemon {
        // define properties for a Daemon
        string Id;
    }

    mapping(uint256 => Daemon) public daemons;
    mapping(uint256 => mapping(uint256=>Incident)) public daemonIncidents;
    mapping(address => bool) public validators;

    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event IncidentReported(uint256 indexed daemonId, uint256 indexed incidentId);

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

    function addIncident(uint256 daemonId, uint256 incidentId, Incident memory incident) public {
        require(validators[msg.sender], "Only validators can report incidents.");
        // add the incident to the registry
        daemonIncidents[daemonId][incidentId] = incident;
        incidentCount++;
        emit IncidentReported(daemonId, incidentId);
        console.log("Incident reported: daemonId=%s, incidentId=%s, count=%d", daemonId, incidentId, incidentCount);
    }

//    function getIncidentsByDaemon(uint256 daemonId) public view returns (Incident[] memory) {
//        // return a list of incidents for the given daemon
//        Incident[] memory incidents = new Incident[](incidentCount);
//        for (uint256 i = 0; i < incidentCount; i++) {
//            incidents[i] = daemonIncidents[daemonId][i];
//        }
//        return incidents;
//    }

    function getIncidentsSinceByDaemon(uint256 daemonId, uint256 sinceTimestamp) public view returns (Incident[] memory) {
        // return a list of incidents for the given daemon since the given timestamp
        uint256 count = 0;
        for (uint256 i = 0; i < incidentCount; i++) {
            if (daemonIncidents[daemonId][i].CreatedAt >= sinceTimestamp) {
                count++;
            }
        }
        console.log("Incidents since %s: %d", sinceTimestamp, count);
        Incident[] memory incidents = new Incident[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < incidentCount; i++) {
            if (daemonIncidents[daemonId][i].CreatedAt >= sinceTimestamp) {
                incidents[index] = daemonIncidents[daemonId][i];
                index++;
            }
        }
        console.log("Incidents since %s: %d", sinceTimestamp, count);
        return incidents;
    }

    function hasIncidents(uint256 daemonId, uint256 sinceTimestamp) public view returns (bool) {
        // return true if the given daemon has any incidents since the given timestamp
        for (uint256 i = 0; i < incidentCount; i++) {
            if (daemonIncidents[daemonId][i].CreatedAt >= sinceTimestamp) {
                console.log("Incident found: daemonId=%s, incidentId=%s, count=%d", daemonId, i, incidentCount);
                return true;
            }
        }
        return false;
    }
    //todo
    function setIncidentsByDaemon(uint256 daemonId, Incident[] memory incidents) public {
        for (uint256 i = 0; i < incidents.length; i++) {
            daemonIncidents[daemonId][i] = incidents[i];
        }
        incidentCount++;
    }

    //todo
    function getIncidentsByDaemon(uint256 daemonId) public view returns (Incident[] memory) {
        Incident[] memory incidents = new Incident[](incidentCount);
        for (uint256 i = 0; i < incidentCount; i++) {
            incidents[i] = daemonIncidents[daemonId][i];
        }
        return incidents;
    }
}

