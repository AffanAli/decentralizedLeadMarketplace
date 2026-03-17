// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LeadRegistry.sol";

contract EscrowVault is Ownable {
    enum OrderState {
        Pending,
        Completed,
        Refunded,
        Disputed
    }

    struct Order {
        address buyer;
        address seller;
        uint256 listingId;
        uint256 amount;
        OrderState state;
        uint256 createdAt;
    }

    IERC20 public token;
    LeadRegistry public leadRegistry;
    address public disputeManager;
    uint256 public orderCounter;
    mapping(uint256 => Order) public orders;

    event OrderCreated(uint256 indexed orderId, uint256 indexed listingId, address indexed buyer, address seller, uint256 amount);
    event EscrowReleased(uint256 indexed orderId);
    event BuyerRefunded(uint256 indexed orderId);
    event OrderMarkedDisputed(uint256 indexed orderId);
    event DisputeManagerSet(address indexed disputeManagerAddress);

    error InvalidListing();
    error InvalidOrder();
    error UnauthorizedDisputeManager();
    error InvalidOrderState();
    error TransferFailed();

    constructor(address _token, address _leadRegistry, address _owner) Ownable(_owner) {
        token = IERC20(_token);
        leadRegistry = LeadRegistry(_leadRegistry);
    }

    modifier onlyDisputeManager() {
        if (msg.sender != disputeManager) revert UnauthorizedDisputeManager();
        _;
    }

    function setDisputeManager(address _disputeManager) external onlyOwner {
        disputeManager = _disputeManager;
        emit DisputeManagerSet(_disputeManager);
    }

    function createOrder(uint256 _listingId) external returns (uint256) {
        LeadRegistry.Listing memory listing = leadRegistry.getListing(_listingId);
        if (listing.seller == address(0)) revert InvalidListing();
        if (listing.status != LeadRegistry.LeadStatus.Listed) revert InvalidListing();

        orderCounter += 1;
        orders[orderCounter] = Order({
            buyer: msg.sender,
            seller: listing.seller,
            listingId: _listingId,
            amount: listing.price,
            state: OrderState.Pending,
            createdAt: block.timestamp
        });

        bool success = token.transferFrom(msg.sender, address(this), listing.price);
        if (!success) revert TransferFailed();

        leadRegistry.markSold(_listingId);
        emit OrderCreated(orderCounter, _listingId, msg.sender, listing.seller, listing.price);
        return orderCounter;
    }

    function releaseEscrow(uint256 _orderId) external onlyOwner {
        Order storage order = orders[_orderId];
        if (order.buyer == address(0)) revert InvalidOrder();
        if (order.state != OrderState.Pending) revert InvalidOrderState();

        order.state = OrderState.Completed;
        bool success = token.transfer(order.seller, order.amount);
        if (!success) revert TransferFailed();

        leadRegistry.markResolved(order.listingId);
        emit EscrowReleased(_orderId);
    }

    function refundBuyer(uint256 _orderId) external onlyDisputeManager {
        Order storage order = orders[_orderId];
        if (order.buyer == address(0)) revert InvalidOrder();
        if (order.state != OrderState.Disputed && order.state != OrderState.Pending) revert InvalidOrderState();

        order.state = OrderState.Refunded;
        bool success = token.transfer(order.buyer, order.amount);
        if (!success) revert TransferFailed();

        leadRegistry.markResolved(order.listingId);
        emit BuyerRefunded(_orderId);
    }


    function getOrder(uint256 _orderId) external view returns (Order memory) {
        Order memory order = orders[_orderId];
        if (order.buyer == address(0)) revert InvalidOrder();
        return order;
    }

    function markDisputed(uint256 _orderId) external onlyDisputeManager {
        Order storage order = orders[_orderId];
        if (order.buyer == address(0)) revert InvalidOrder();
        if (order.state != OrderState.Pending) revert InvalidOrderState();

        order.state = OrderState.Disputed;
        leadRegistry.markDisputed(order.listingId);
        emit OrderMarkedDisputed(_orderId);
    }
}
