// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ReputationManager is Ownable {
    mapping(address => uint256) public scores;
    mapping(address => uint256) public successfulSales;
    mapping(address => uint256) public disputesLost;

    event ReputationUpdated(address indexed seller, bool positive, uint256 newScore);

    constructor(address _owner) Ownable(_owner) {}

    function updateReputation(address _seller, bool _positive) external onlyOwner {
        if (_positive) {
            successfulSales[_seller] += 1;
            scores[_seller] += 10;
        } else {
            disputesLost[_seller] += 1;
            if (scores[_seller] >= 5) {
                scores[_seller] -= 5;
            } else {
                scores[_seller] = 0;
            }
        }

        emit ReputationUpdated(_seller, _positive, scores[_seller]);
    }

    function getReputation(address _seller) external view returns (uint256) {
        return scores[_seller];
    }
}
