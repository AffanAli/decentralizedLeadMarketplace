// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LeadToken is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 1_000_000 ether;
    address public saleContract;

    error SaleContractNotSet();
    error UnauthorizedSaleContract();
    error MaxSupplyExceeded();

    constructor(address _owner) ERC20("LeadToken", "LEAD") Ownable(_owner) {}

    function setSaleContract(address _saleContract) external onlyOwner {
        saleContract = _saleContract;
    }

    function mint(address _to, uint256 _amount) external {
        if (saleContract == address(0)) revert SaleContractNotSet();
        if (msg.sender != saleContract) revert UnauthorizedSaleContract();
        if (totalSupply() + _amount > MAX_SUPPLY) revert MaxSupplyExceeded();
        _mint(_to, _amount);
    }
}
