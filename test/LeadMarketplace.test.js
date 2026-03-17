const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Lead Marketplace CW1 Scaffold", function () {
  async function deployFixture() {
    const [owner, buyer, seller, arbitrator] = await ethers.getSigners();

    const LeadToken = await ethers.getContractFactory("LeadToken");
    const leadToken = await LeadToken.deploy(owner.address);
    await leadToken.waitForDeployment();

    const TokenSale = await ethers.getContractFactory("TokenSale");
    const tokenSale = await TokenSale.deploy(await leadToken.getAddress(), 1000n, owner.address);
    await tokenSale.waitForDeployment();
    await leadToken.setSaleContract(await tokenSale.getAddress());

    const LeadRegistry = await ethers.getContractFactory("LeadRegistry");
    const leadRegistry = await LeadRegistry.deploy(owner.address);
    await leadRegistry.waitForDeployment();

    const EscrowVault = await ethers.getContractFactory("EscrowVault");
    const escrowVault = await EscrowVault.deploy(
      await leadToken.getAddress(),
      await leadRegistry.getAddress(),
      owner.address
    );
    await escrowVault.waitForDeployment();
    await leadRegistry.setEscrowVault(await escrowVault.getAddress());

    const ReputationManager = await ethers.getContractFactory("ReputationManager");
    const reputationManager = await ReputationManager.deploy(owner.address);
    await reputationManager.waitForDeployment();

    const DisputeManager = await ethers.getContractFactory("DisputeManager");
    const disputeManager = await DisputeManager.deploy(
      await escrowVault.getAddress(),
      await leadRegistry.getAddress(),
      await reputationManager.getAddress(),
      owner.address
    );
    await disputeManager.waitForDeployment();

    await escrowVault.setDisputeManager(await disputeManager.getAddress());
    await disputeManager.setArbitrator(arbitrator.address);

    return {
      owner,
      buyer,
      seller,
      arbitrator,
      leadToken,
      tokenSale,
      leadRegistry,
      escrowVault,
      disputeManager,
      reputationManager
    };
  }

  it("deploys token with correct metadata", async function () {
    const { leadToken } = await deployFixture();
    expect(await leadToken.name()).to.equal("LeadToken");
    expect(await leadToken.symbol()).to.equal("LEAD");
  });

  it("allows a buyer to purchase tokens through the ICO", async function () {
    const { buyer, tokenSale, leadToken } = await deployFixture();

    await expect(
      tokenSale.connect(buyer).buyTokens({ value: ethers.parseEther("1") })
    ).to.emit(tokenSale, "TokensPurchased");

    expect(await leadToken.balanceOf(buyer.address)).to.equal(ethers.parseEther("1000"));
  });

  it("creates a lead listing", async function () {
    const { seller, leadRegistry } = await deployFixture();
    const expiry = BigInt((await ethers.provider.getBlock("latest")).timestamp + 3600);
    const leadHash = ethers.keccak256(ethers.toUtf8Bytes("lead-001"));

    await expect(leadRegistry.connect(seller).createListing(leadHash, ethers.parseEther("50"), expiry))
      .to.emit(leadRegistry, "ListingCreated");

    const listing = await leadRegistry.getListing(1);
    expect(listing.seller).to.equal(seller.address);
    expect(listing.price).to.equal(ethers.parseEther("50"));
  });

  it("creates an escrow order after token approval", async function () {
    const { buyer, seller, tokenSale, leadToken, leadRegistry, escrowVault } = await deployFixture();

    await tokenSale.connect(buyer).buyTokens({ value: ethers.parseEther("1") });
    const expiry = BigInt((await ethers.provider.getBlock("latest")).timestamp + 3600);
    const leadHash = ethers.keccak256(ethers.toUtf8Bytes("lead-escrow"));
    await leadRegistry.connect(seller).createListing(leadHash, ethers.parseEther("50"), expiry);

    await leadToken.connect(buyer).approve(await escrowVault.getAddress(), ethers.parseEther("50"));

    await expect(escrowVault.connect(buyer).createOrder(1))
      .to.emit(escrowVault, "OrderCreated");

    const order = await escrowVault.orders(1);
    expect(order.buyer).to.equal(buyer.address);
    expect(order.seller).to.equal(seller.address);
  });
});
