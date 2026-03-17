// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./LeadToken.sol";

contract TokenSale is Ownable {
    LeadToken public token;
    uint256 public rate;
    uint256 public ethRaised;
    bool public saleActive;

    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event RateUpdated(uint256 oldRate, uint256 newRate);
    event SaleToggled(bool active);
    event FundsWithdrawn(address indexed owner, uint256 amount);

    error SaleInactive();
    error ZeroEthSent();
    error InvalidRate();

    constructor(address _token, uint256 _rate, address _owner) Ownable(_owner) {
        if (_rate == 0) revert InvalidRate();
        token = LeadToken(_token);
        rate = _rate;
        saleActive = true;
    }

    function buyTokens() external payable {
        if (!saleActive) revert SaleInactive();
        if (msg.value == 0) revert ZeroEthSent();

        uint256 tokenAmount = getTokenAmount(msg.value);
        ethRaised += msg.value;
        token.mint(msg.sender, tokenAmount);

        emit TokensPurchased(msg.sender, msg.value, tokenAmount);
    }

    function setRate(uint256 _rate) external onlyOwner {
        if (_rate == 0) revert InvalidRate();
        uint256 oldRate = rate;
        rate = _rate;
        emit RateUpdated(oldRate, _rate);
    }

    function toggleSale(bool _active) external onlyOwner {
        saleActive = _active;
        emit SaleToggled(_active);
    }

    function withdrawFunds() external onlyOwner {
        uint256 amount = address(this).balance;
        payable(owner()).transfer(amount);
        emit FundsWithdrawn(owner(), amount);
    }

    function getTokenAmount(uint256 _ethAmount) public view returns (uint256) {
        return _ethAmount * rate;
    }
}
