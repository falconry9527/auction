const { ethers } = require("hardhat")
const { describe } = require("mocha")

describe("starting ", function () {

    it("should deploy the contract", async function () {
        const NftAuction = await ethers.getContractFactory("NftAuction")
        const nftAuction = await NftAuction.deploy()
        await nftAuction.waitForDeployment()

        console.log("NftAuction deployed to:", nftAuction.address)

        // 检查管理员地址
        const admin = await nftAuction.admin()
        console.log("Admin address:", admin)

        // 检查合约余额
        const balance = await ethers.provider.getBalance(nftAuction.address)
        console.log("Contract balance:", ethers.utils.formatEther(balance))

        nftAuction.createAuction(100, ethers.parseEther("0.0000001"), ethers.ZeroAddress, 1)
        nftAuction.auctions(1).then(auction => {
            console.log("Auction details:", auction)
        })


    })
})
