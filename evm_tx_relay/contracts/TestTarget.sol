// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract TestTarget {
    // State variable to store data from function calls
    bytes public lastData;

    // Function to simulate an external contract call
    function testFunction(bytes memory _data) public {
        lastData = _data;
    }
}
