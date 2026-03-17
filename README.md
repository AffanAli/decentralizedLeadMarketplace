# Decentralized Lead Marketplace

A decentralized marketplace for buying and selling digital leads on Ethereum. Sellers list leads; buyers pay with the native **LeadToken** (ERC20). Escrow, reputation, and disputes are handled on-chain.

## Tech Stack

- **Solidity** 0.8.24
- **Hardhat** (compile & test)
- **OpenZeppelin** contracts (ERC20, Ownable)

## Contracts

| Contract | Purpose |
|----------|---------|
| **LeadToken** | ERC20 token (LEAD), max supply 1M. Minted via TokenSale only. |
| **TokenSale** | Buy LEAD with ETH at a configurable rate. Owner can set rate and toggle sale. |
| **LeadRegistry** | Listings: seller, lead hash, price, status (Listed / Sold / Disputed / Resolved), expiry. Only EscrowVault can mark sold/disputed/resolved. |
| **EscrowVault** | Holds buyer payment in LEAD; creates orders, releases to seller or refunds buyer. Integrates with DisputeManager. |
| **ReputationManager** | Seller scores: +10 on successful sale, −5 on dispute loss (min 0). Tracks successful sales and disputes lost. |
| **DisputeManager** | Buyers raise disputes on orders; arbitrator resolves (refund buyer or release to seller). Updates ReputationManager and EscrowVault. |

## Setup & Commands

```bash
npm install
npm run compile
npm test
```

## Test

Tests use Hardhat + ethers and cover deployment, token purchase, listing creation, escrow flow, and dispute resolution.
