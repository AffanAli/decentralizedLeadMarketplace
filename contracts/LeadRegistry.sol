// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LeadRegistry is Ownable {
    enum LeadStatus {
        Listed,
        Sold,
        Disputed,
        Resolved
    }

    struct Listing {
        address seller;
        bytes32 leadHash;
        uint256 price;
        LeadStatus status;
        uint256 createdAt;
        uint256 expiresAt;
    }

    uint256 public listingCounter;
    address public escrowVault;
    mapping(uint256 => Listing) public listings;

    event ListingCreated(uint256 indexed listingId, address indexed seller, uint256 price, bytes32 leadHash);
    event ListingStatusChanged(uint256 indexed listingId, LeadStatus status);
    event EscrowVaultSet(address indexed escrowVaultAddress);

    error InvalidPrice();
    error InvalidExpiry();
    error ListingNotFound();
    error UnauthorizedEscrowVault();

    constructor(address _owner) Ownable(_owner) {}

    modifier onlyEscrowVault() {
        if (msg.sender != escrowVault) revert UnauthorizedEscrowVault();
        _;
    }

    function setEscrowVault(address _escrowVault) external onlyOwner {
        escrowVault = _escrowVault;
        emit EscrowVaultSet(_escrowVault);
    }

    function createListing(bytes32 _leadHash, uint256 _price, uint256 _expiresAt) external returns (uint256) {
        if (_price == 0) revert InvalidPrice();
        if (_expiresAt <= block.timestamp) revert InvalidExpiry();

        listingCounter += 1;
        listings[listingCounter] = Listing({
            seller: msg.sender,
            leadHash: _leadHash,
            price: _price,
            status: LeadStatus.Listed,
            createdAt: block.timestamp,
            expiresAt: _expiresAt
        });

        emit ListingCreated(listingCounter, msg.sender, _price, _leadHash);
        return listingCounter;
    }

    function getListing(uint256 _listingId) external view returns (Listing memory) {
        _requireExists(_listingId);
        return listings[_listingId];
    }

    function markSold(uint256 _listingId) external onlyEscrowVault {
        _requireExists(_listingId);
        listings[_listingId].status = LeadStatus.Sold;
        emit ListingStatusChanged(_listingId, LeadStatus.Sold);
    }

    function markDisputed(uint256 _listingId) external onlyEscrowVault {
        _requireExists(_listingId);
        listings[_listingId].status = LeadStatus.Disputed;
        emit ListingStatusChanged(_listingId, LeadStatus.Disputed);
    }

    function markResolved(uint256 _listingId) external onlyEscrowVault {
        _requireExists(_listingId);
        listings[_listingId].status = LeadStatus.Resolved;
        emit ListingStatusChanged(_listingId, LeadStatus.Resolved);
    }

    function _requireExists(uint256 _listingId) internal view {
        if (_listingId == 0 || _listingId > listingCounter) revert ListingNotFound();
    }
}
