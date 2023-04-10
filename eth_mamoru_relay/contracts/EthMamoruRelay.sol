// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
//import "hardhat/console.sol";

contract EthMamoruRelay is Ownable {

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

    // define a mapping to store the number of incidents for each daemon
    mapping(string => uint256)  incidentCount;

    mapping(uint256 => Daemon)  daemons;
    mapping(string => mapping(uint256=>Incident))  daemonIncidents;
    mapping(address => bool)  validators;

    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event IncidentReported(string indexed daemonId, string indexed incidentId);

    function addValidator(address validator) public onlyOwner {
        validators[validator] = true;
        emit ValidatorAdded(validator);
        //console.log("Validator added: %s", validator);
    }

    function removeValidator(address validator) public onlyOwner {
        delete validators[validator];
        emit ValidatorRemoved(validator);
        //console.log("Validator removed: %s", validator);
    }

    function addIncident(string memory daemonId, Incident memory incident) public {
        //console.log("Check validator address: %s", msg.sender);
        require(validators[msg.sender], "Only validators can report incidents.");

        // add the incident to the registry
        daemonIncidents[daemonId][incidentCount[daemonId]] = incident;

        emit IncidentReported(daemonId, incident.Id);

        incidentCount[daemonId]++;
        //console.log("Incident reported: daemonId=%s, incidentId=%s count=%d", daemonId, incident.Id, incidentCount[daemonId]);
    }

    function getIncidentsSinceByDaemon(string memory daemonId, uint256 sinceTimestamp) public view returns (Incident[] memory, uint256) {
        // return a list of incidents for the given daemon since the given timestamp

        uint256 count = 0;
        for (uint256 i = incidentCount[daemonId]; i > 0; i--) {
            if (daemonIncidents[daemonId][i-1].CreatedAt >= sinceTimestamp) {
                count++;
            } else {
                break;
            }
        }
        if (count == 0) {
            return (new Incident[](0), 0);
        }

        Incident[] memory incidents = new Incident[](count);
        uint256 index = 0;
        for (uint256 i = incidentCount[daemonId]; i > 0 ; i--) {
            if (daemonIncidents[daemonId][i-1].CreatedAt >= sinceTimestamp) {
                incidents[index] = daemonIncidents[daemonId][i-1];
                index++;
            }
        }
        //console.log("Incidents since %s: %d", sinceTimestamp, count);
        return (incidents, count);
    }

    function hasIncidents(string memory daemonId, uint64 sinceTimestamp) public view returns (bool) {
        // return true if the given daemon has any incidents since the given timestamp
        for (uint256 i = 0; i < incidentCount[daemonId]; i++) {
            if (daemonIncidents[daemonId][i].CreatedAt >= sinceTimestamp) {
                //console.log("Incident found: daemonId=%s, count=%d", daemonId, i);
                return true;
            }
        }
        return false;
    }
}

