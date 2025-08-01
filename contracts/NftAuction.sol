// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// 默认是 UUPS 代理
contract NftAuction is Initializable, UUPSUpgradeable {
    // 结构体
    struct Auction {
        // 卖家
        address seller;
        // 拍卖持续时间
        uint256 duration;
        // 起始价格
        uint256 startPrice;
        // 开始时间
        uint256 startTime;
        // 是否结束
        bool ended;
        // 最高出价者
        address highestBidder;
        // 最高价格
        uint256 highestBid;
        // NFT合约地址
        address nftContract;
        // NFT ID
        uint256 tokenId;
        address tokenAddress;
    }

    // 状态变量
    mapping(uint256 => Auction) public auctions;
    // 下一个拍卖ID
    uint256 public nextAuctionId;
    // 管理员地址
    address public admin;
    // Chainlink价格预言机映射
    mapping(address => AggregatorV3Interface) public priceFeeds;

    // 使用 一般部署的时候，需要打开 构造函数，关闭 initialize
    // 使用 upgrades 的时候，则相反
    // constructor() {
    //     admin = msg.sender;
    // }
    // 创建拍卖
    function createAuction(
        uint256 _duration,
        uint256 _startPrice,
        address _nftAddress,
        uint256 _tokenId
    ) public {
        // 只有管理员可以创建拍卖
        console.log("createAuction", msg.sender, admin);
        console.log("msg.sender.balance", msg.sender.balance);

        require(msg.sender == admin, "Only admin can create auctions");
        // 检查参数
        require(_duration >= 10, "Duration must be greater than 10s");
        require(_startPrice > 0, "Start price must be greater than 0");

        // 转移NFT到合约
        // IERC721(_nftAddress).safeTransferFrom(
        //     msg.sender,
        //     address(this),
        //     _tokenId
        // );

        auctions[nextAuctionId] = Auction({
            seller: msg.sender,
            duration: _duration,
            startPrice: _startPrice,
            ended: false,
            highestBidder: address(0),
            highestBid: 0,
            startTime: block.timestamp,
            nftContract: _nftAddress,
            tokenId: _tokenId,
            tokenAddress: address(0)
        });

        nextAuctionId++;
    }

    function getChainlinkDataFeedLatestAnswer(
        address tokenAddress
    ) public view returns (int) {
        AggregatorV3Interface priceFeed = priceFeeds[tokenAddress];
        (
            ,
            /* uint80 roundId */ int256 answer /*uint256 startedAt*/ /*uint256 updatedAt*/ /*uint80 answeredInRound*/,
            ,
            ,

        ) = priceFeed.latestRoundData();
        return answer;
    }

    // 进行拍卖
    function placeBid(
        uint256 _auctionID,
        uint256 amount,
        address _tokenAddress
    ) external payable {
        // 统一的价值尺度
        Auction storage auction = auctions[_auctionID];
        // 判断当前拍卖是否结束
        require(!auction.ended, "Auction has ended");
        require(
            (auction.startTime + auction.duration) < block.timestamp,
            "Auction has ended"
        );
        // 判断出价是否大于当前最高出价
        uint payValue;
        if (_tokenAddress != address(0)) {
            // 处理 ERC20
            // 检查是否是 ERC20 资产
            payValue =
                amount *
                uint(getChainlinkDataFeedLatestAnswer(_tokenAddress));
        } else {
            // 处理 ETH
            amount = msg.value;
            payValue =
                amount *
                uint(getChainlinkDataFeedLatestAnswer(address(0)));
        }

        uint startPriceValue = auction.startPrice *
            uint(getChainlinkDataFeedLatestAnswer(auction.tokenAddress));
        uint highestBidValue = auction.highestBid *
            uint(getChainlinkDataFeedLatestAnswer(auction.tokenAddress));
        require(
            payValue >= startPriceValue && payValue > highestBidValue,
            "Bid must be higher than the current highest bid"
        );
        // 转移 ERC20 到合约
        if (_tokenAddress != address(0)) {
            IERC20(_tokenAddress).transferFrom(
                msg.sender,
                address(this),
                amount
            );
        }
        // 退还前最高价
        if (auction.highestBid > 0) {
            if (auction.tokenAddress == address(0)) {
                // auction.tokenAddress = _tokenAddress;
                payable(auction.highestBidder).transfer(auction.highestBid);
            } else {
                // 退回之前的ERC20
                IERC20(auction.tokenAddress).transfer(
                    auction.highestBidder,
                    auction.highestBid
                );
            }
        }

        auction.tokenAddress = _tokenAddress;
        auction.highestBid = amount;
        auction.highestBidder = msg.sender; // _tokenAddress
    }

    // 结束拍卖
    function endAuction(uint256 _auctionID) external {
        Auction storage auction = auctions[_auctionID];
        console.log(
            "endAuction",
            auction.startTime,
            auction.duration,
            block.timestamp
        );
        // 判断当前拍卖是否结束
        require(!auction.ended, "Auction has ended");
        require(
            (auction.startTime + auction.duration) < block.timestamp,
            "Auction has ended"
        );
        // 转移NFT到最高出价者
        IERC721(auction.nftContract).safeTransferFrom(
            address(this),
            auction.highestBidder,
            auction.tokenId
        );
        // 转移剩余的资金到卖家
        auction.ended = true;
    }

    function initialize() public initializer {
        admin = msg.sender;
    }

    function _authorizeUpgrade(address) internal view override {
        // 只有管理员可以升级合约
        require(msg.sender == admin, "Only admin can upgrade");
    }

}
