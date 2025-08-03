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

  it("test createAuction ...", async function () {
     // 模拟4个用户
    [owner, seller, bidder1, bidder2] = await ethers.getSigners();
    // 获取 solidity 的类，从而调用方法
    NftAuction = await ethers.getContractFactory("NftAuction");
    // 一. 部署 本合约
    proxy = await upgrades.deployProxy(NftAuction, [10,1], {
      kind: "uups",
      initializer: "initialize"
    });
    await proxy.waitForDeployment();
    const proxyAddress=await proxy.getAddress() 
    const impAddress=await upgrades.erc1967.getImplementationAddress(proxyAddress)
    console.log("本合约部署成功 地址::", proxyAddress);

    // 二. 部署一个 NFT 用来拍卖
    // 部署一个NFT TestERC721 
    const TestERC721 = await ethers.getContractFactory("TestERC721");
    const testERC721 = await TestERC721.deploy();
    await testERC721.waitForDeployment();
    const testERC721Address = await testERC721.getAddress();
    console.log("NFT 部署成功 testERC721Address::", testERC721Address);

    // 2. 铸造一些 NFT 给 seller
    for (let i = 0; i < 10; i++) {
        await testERC721.mint(seller.address, i + 1);
        console.log(" 给seller 铸造币::", i+1);
    }
    // 3. 授权 NftAuction 能对 NFT 进行转账
    await testERC721.connect(seller).setApprovalForAll(proxyAddress, true);
    await testERC721.connect(seller).setApprovalForAll(impAddress, true);
    console.log("授权成功");

    // 三. 创建拍卖
    // 1. owner 允许代理合约使用 NFT
    await proxy.connect(owner).approveNftContract(testERC721Address);
    console.log("允许拍卖:",testERC721Address);

    // 2. seller 创建一个 拍卖
    const tokenId=2 ;
    await proxy.connect(seller).createAuction(testERC721Address,tokenId, 1000, 100000000);

    // 3. 出价
    // await proxy.connect(bidder1).placeBid(0, { value: ethers.parseEther("1.5") });
    // const auction = await proxy.getAuction(0);
    // expect(auction.highestBidder).to.equal(bidder1.address);

  });


  // it("test v2 new function", async function () {
  //   // 升级到V2
  //   NftAuctionV2 = await ethers.getContractFactory("NftAuctionV2");
  //   const upgraded = await upgrades.upgradeProxy(await proxy.getAddress(), NftAuctionV2);

  //   // 验证状态保持
  //   const auction = await upgraded.getAuction(0);
  //   expect(auction.highestBidder).to.equal(bidder1.address);

  //   // 测试新功能
  //   expect(await upgraded.version()).to.equal("V2");
  // });

});