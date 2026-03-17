// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./EscrowVault.sol";
import "./LeadRegistry.sol";
import "./ReputationManager.sol";

contract DisputeManager is Ownable {
    enum DisputeState {
        Open,
        Resolved
    }

    struct Dispute {
        uint256 orderId;
        address buyer;
        string reason;
        DisputeState state;
    }

    address public arbitrator;
    EscrowVault public escrowVault;
    LeadRegistry public leadRegistry;
    ReputationManager public reputationManager;
    uint256 public disputeCounter;
    mapping(uint256 => Dispute) public disputes;

    event DisputeRaised(uint256 indexed disputeId, uint256 indexed orderId, address indexed buyer, string reason);
    event DisputeResolved(uint256 indexed disputeId, bool refundBuyer);
    event ArbitratorSet(address indexed arbitratorAddress);

    error UnauthorizedArbitrator();
    error InvalidOrder();
    error InvalidDispute();
    error InvalidState();

    constructor(address _escrowVault, address _leadRegistry, address _reputationManager, address _owner) Ownable(_owner) {
        escrowVault = EscrowVault(_escrowVault);
        leadRegistry = LeadRegistry(_leadRegistry);
        reputationManager = ReputationManager(_reputationManager);
    }

    modifier onlyArbitrator() {
        if (msg.sender != arbitrator) revert UnauthorizedArbitrator();
        _;
    }

    function setArbitrator(address _arbitrator) external onlyOwner {
        arbitrator = _arbitrator;
        emit ArbitratorSet(_arbitrator);
    }

    function raiseDispute(uint256 _orderId, string calldata _reason) external returns (uint256) {
        EscrowVault.Order memory order = escrowVault.getOrder(_orderId);
        if (order.buyer == address(0)) revert InvalidOrder();
        if (order.buyer != msg.sender) revert InvalidOrder();

        disputeCounter += 1;
        disputes[disputeCounter] = Dispute({
            orderId: _orderId,
            buyer: msg.sender,
            reason: _reason,
            state: DisputeState.Open
        });

        escrowVault.markDisputed(_orderId);
        emit DisputeRaised(disputeCounter, _orderId, msg.sender, _reason);
        return disputeCounter;
    }

    function resolveDispute(uint256 _disputeId, bool _refundBuyer) external onlyArbitrator {
        Dispute storage dispute = disputes[_disputeId];
        if (dispute.buyer == address(0)) revert InvalidDispute();
        if (dispute.state != DisputeState.Open) revert InvalidState();

        dispute.state = DisputeState.Resolved;

        EscrowVault.Order memory order = escrowVault.getOrder(dispute.orderId);
        if (_refundBuyer) {
            escrowVault.refundBuyer(dispute.orderId);
            reputationManager.updateReputation(order.seller, false);
        } else {
            reputationManager.updateReputation(order.seller, true);
        }

        emit DisputeResolved(_disputeId, _refundBuyer);
    }
}
