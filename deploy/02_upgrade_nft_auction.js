const { ethers, upgrades } = require("hardhat")
const fs = require("fs")
const path = require("path")

module.exports = async function ({ getNamedAccounts, deployments }) {
  const { save } = deployments
  const { deployer } = await getNamedAccounts()
  console.log("部署用户地址 V2：", deployer)

  // 读取 .cache/proxyNftAuction.json文件
  const storePath = path.resolve(__dirname, "../deployments/sepolia/NftAuctionProxy.json");
  const storeData = fs.readFileSync(storePath, "utf-8");
  const { address } = JSON.parse(storeData);

  // 获取合约工厂
  const NftAuctionV2 = await ethers.getContractFactory("NftAuctionV2")

  // 升级代理合约
  const nftAuctionProxyV2 = await upgrades.upgradeProxy(address, NftAuctionV2, { kind: "uups" })
  console.log("升级中...");
  await nftAuctionProxyV2.waitForDeployment()

  const proxyAddressV2 = await nftAuctionProxyV2.getAddress()
  const impAddressV2 = await upgrades.erc1967.getImplementationAddress(proxyAddressV2)
  console.log("代理合约地址 V2：", proxyAddressV2);
  console.log("实现合约地址 V2：", impAddressV2);


  // 验证新功能
  console.log("验证新功能 Contract version:", await nftAuctionProxyV2.version());

  // 保存合约信息
  await save("NftAuctionProxyV2", {
    from: deployer.address,
    abi: NftAuctionV2.interface.format("json"),
    adress: proxyAddressV2,
    log: false,
  })
}


module.exports.tags = ['upgradeNftAuction']