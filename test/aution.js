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

  it("test aution function ...", async function () {
     // 模拟4个用户
    [owner, seller, bidder1, bidder2] = await ethers.getSigners();
    // 获取 solidity 的类，从而调用方法
    NftAuction = await ethers.getContractFactory("NftAuction");
    // 一. 合约准备
    // 1.主合约: 拍卖合约
    proxy = await upgrades.deployProxy(NftAuction, [10,1], {
      kind: "uups",
      initializer: "initialize"
    });
    await proxy.waitForDeployment();
    const proxyAddress=await proxy.getAddress() 
    const impAddress=await upgrades.erc1967.getImplementationAddress(proxyAddress)
    console.log("本合约部署成功 地址::", proxyAddress);

    // 2. 被拍卖的合约
    // 部署一个NFT TestERC721 
    const TestERC721 = await ethers.getContractFactory("TestERC721");
    const testERC721 = await TestERC721.deploy();
    await testERC721.waitForDeployment();
    const testERC721Address = await testERC721.getAddress();
    console.log("NFT部署成功 testERC721Address::", testERC721Address);
    //  铸造一些 NFT 给 seller
    for (let i = 0; i < 10; i++) {
        await testERC721.mint(seller.address, i + 1);
    }
    // seller 授权 NftAuction 能对 seller的testERC721  进行转账
    await testERC721.connect(seller).setApprovalForAll(proxyAddress, true);
    console.log("NFT 授权成功");

    // 3. 出价的合约 
    const TestERC20 = await ethers.getContractFactory("TestERC20");
    const testERC20 = await TestERC20.deploy();
    await testERC20.waitForDeployment();
    const testERC20Address = await testERC20.getAddress();
    // 初始化币子 并授权合约调用
    await testERC20.connect(bidder1).mint();
    await testERC20.connect(bidder2).mint();
    await testERC20.connect(bidder1).approve(proxyAddress, 100000000);
    await testERC20.connect(bidder2).approve(proxyAddress, 100000000);

    console.log("出价ERC20 testERC20 授权成功");


    // 三. 创建拍卖
    // 1. owner 允许使用 testERC721Address 进行拍卖
    await proxy.connect(owner).approveNftContract(testERC721Address);
    console.log("允许拍卖:",testERC721Address);

    // 2. seller 创建一个 拍卖
    const tokenId=2 ;
    await proxy.connect(seller).createAuction(testERC721Address,tokenId, 1000, 100000000);
    const auction = await proxy.getAuction(1);
    console.log("创建拍卖会成功...",auction);

    // 四. 出价
    // 1. 添加预言机对
    await proxy.connect(owner).setPriceFeed(testERC20Address,testERC20Address);
    console.log("添加预言机对成功...");
    // 出价
    await proxy.connect(bidder1).placeBid(1, testERC20Address,1000);
    const auction1 = await proxy.getAuction(1);
    console.log("出价成功1次...",auction1);
    await proxy.connect(bidder2).placeBid(1, testERC20Address,2000);
    const auction2 = await proxy.getAuction(1);
    console.log("出价成功2次...",auction2);
    expect(auction2.highestBidder).to.equal(bidder2.address);

  });


  it("test v2 new function", async function () {
    // 升级到V2
    NftAuctionV2 = await ethers.getContractFactory("NftAuctionV2");
    const upgraded = await upgrades.upgradeProxy(await proxy.getAddress(), NftAuctionV2);

    // 测试新功能
    expect(await upgraded.version()).to.equal("V2");
  });

});