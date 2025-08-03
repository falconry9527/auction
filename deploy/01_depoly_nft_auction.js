const {upgrades, ethers } = require("hardhat");
const path = require("path");

// deploy/00_deploy_my_contract.js
module.exports = async ({ getNamedAccounts, deployments }) => {
  const { save } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log("部署用户地址：", deployer);
  // 获取合约工厂
  const NftAuction = await ethers.getContractFactory("NftAuction");

  // 通过代理合约部署
  const nftAuctionProxy = await upgrades.deployProxy(NftAuction, [10, 1], {
    initializer: "initialize",
    kind: "uups",
    from: deployer,
    log: true,
  });
  console.log("部署中...");
  await nftAuctionProxy.waitForDeployment();

  const proxyAddress=await nftAuctionProxy.getAddress() 
  const impAddress=await upgrades.erc1967.getImplementationAddress(proxyAddress)
  console.log("代理合约地址：", proxyAddress);
  console.log("实现合约地址：", impAddress);

  // 保存合约信息
  await save("NftAuctionProxy", {
    from: deployer.address,
    abi: NftAuction.interface.format("json"),
    address: proxyAddress,
    log: false,
  })
};

module.exports.tags = ['deployNftAuction'];

