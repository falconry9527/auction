const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("NftAuction (UUPS Upgradeable)", function () {
  let NftAuction;
  let NftAuctionV2;
  let proxy;
  let owner;
  let seller;
  let bidder1;
  let bidder2;

  beforeEach(async function () {
    // 模拟4个用户
    [owner, seller, bidder1, bidder2] = await ethers.getSigners();
    // 获取 solidity 的类，从而调用方法
    NftAuction = await ethers.getContractFactory("NftAuction");
    // 部署合约
    proxy = await upgrades.deployProxy(NftAuction, [], {
      kind: "uups",
      initializer: "initialize"
    });

    await proxy.waitForDeployment();
    console.log("部署合约=====:");

  });

  it("Should deploy with UUPS proxy", async function () {
    const implementationAddress = await upgrades.erc1967.getImplementationAddress(await proxy.getAddress());
    console.log("实现合约地址 address:", implementationAddress);
    expect(implementationAddress).to.not.equal(await proxy.getAddress());
  });

  it("Should create and bid on auctions", async function () {
    await proxy.connect(seller).createAuction("gyyhkjb", 1, 24);
    await proxy.connect(bidder1).placeBid(0, { value: ethers.parseEther("1.5") });
    const auction = await proxy.getAuction(0);
    expect(auction.highestBidder).to.equal(bidder1.address);
  });

  it("Should upgrade to V2 and maintain state", async function () {
    // 先创建一些状态
    await proxy.connect(seller).createAuction("gyyhkjb", 1, 1);
    await proxy.connect(bidder1).placeBid(0, { value: ethers.parseEther("1.5") });

    // 升级到V2
    NftAuctionV2 = await ethers.getContractFactory("NftAuctionV2");
    const upgraded = await upgrades.upgradeProxy(await proxy.getAddress(), NftAuctionV2);

    // 验证状态保持
    const auction = await upgraded.getAuction(0);
    expect(auction.highestBidder).to.equal(bidder1.address);

    // 测试新功能
    expect(await upgraded.version()).to.equal("V2");
  });

  it("Should extend auction when bid placed near end", async function () {
    // 部署并升级到V2
    NftAuctionV2 = await ethers.getContractFactory("NftAuctionV2");
    const upgraded = await upgrades.upgradeProxy(await proxy.getAddress(), NftAuctionV2);

    // 创建拍卖（1小时持续时间）
    await upgraded.connect(seller).createAuction("gyyhkjb"+new Date().getTime(), 1, 1);

    // 获取当前时间
    const startBlock = await ethers.provider.getBlock("latest");
    const startTime = startBlock.timestamp;

    // 快进到结束前14分钟（60 - 14 = 46分钟已过）
    await network.provider.send("evm_increaseTime", [46 * 60]);
    await network.provider.send("evm_mine"); // 挖一个新块

    // 验证当前时间
    const currentBlock = await ethers.provider.getBlock("latest");
    expect(currentBlock.timestamp).to.be.closeTo(
      startTime + 46 * 60,
      5 // 允许5秒误差
    );

    // 出价应触发延长机制
    await expect(
      upgraded.connect(bidder1).placeBid(0, { value: ethers.parseEther("1.5") })
    ).to.emit(upgraded, "AuctionExtended");

    // 检查拍卖结束时间是否延长
    const auction = await upgraded.getAuction(0);
    console.log("开始时间:", auction.startTime);
    console.log("结束时间:", auction.endTime);
    console.log("延长时间:", BigInt(currentBlock.timestamp + 15 * 60));

    /**
     * -gt：大于（greater than）
      -ge：大于等于（greater than or equal to）
      -lt：小于（less than）
      -le：小于等于（less than or equal to）
      -eq：等于（equal）
      -ne：不等于（not equal to）
     */
    expect(auction.endTime).to.gte(BigInt(currentBlock.timestamp + 15 * 60)); // 延长15分钟
  });
});