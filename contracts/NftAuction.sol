// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";


contract NftAuction is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    IERC721Receiver
{
    // Auction structure
    struct Auction {
        address seller; // 卖家地址
        address nftContract; // 拍卖的NFT
        uint256 tokenId; // 拍卖的NFT ID
        uint256 startTime;
        uint256 endTime;
        uint256 startPrice;
        address highestBidder; // 最高出价的用户地址
        uint256 highestBid; // 出的最高价（换算成USDT）
        bool ended;
        address highestBidToken ; // 代币合约地址： 最高出价
        uint256 highestBidAmount; // 代币数量 ：最高出价
    }

    // Mapping of auction ID to Auction
    // 拍卖集合
    mapping(uint256 => Auction) public auctions;

    // 拍卖ID
    uint256 public nextAuctionId;

    // 最小的拍卖持续时间
    uint256 public minAuctionDuration;

    // Platform fee percentage (1 = 1%)
    // 拍卖手续费
    uint256 public platformFeePercentage;

    // 收手续费的地址
    address public feeRecipient;

    // 拍卖地址是否被允许的mapping
    mapping(address => bool) public approvedNftContracts;


    // 一些事件
    // 拍卖被创建事件，打印日志
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        uint256 startTime,
        uint256 endTime,
        uint256 startPrice
    );
    // 出价事件
    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount
    );
    // 拍卖结束事件
    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 amount
    );
    // 取消拍卖事件
    event AuctionCancelled(uint256 indexed auctionId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        uint256 _minAuctionDuration,
        uint256 _platformFeePercentage
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        minAuctionDuration = _minAuctionDuration;
        platformFeePercentage = _platformFeePercentage;
        feeRecipient = msg.sender;
        nextAuctionId = 1;
        
        // 初始化常用代币价格预言机 (示例)
       // priceFeeds[0x6B175474E89094C44Da98b954EedeAC495271d0F] = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9; // DAI/USD
       // priceFeeds[0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // WETH/USD
        
    }
    mapping(address => address) public priceFeeds; // ERC20 => Chainlink 价格预言机

    // 添加/更新代币价格预言机
    function setPriceFeed(address token, address aggregator) external onlyOwner {
        priceFeeds[token] = aggregator;
    }

    /**
     * @notice 获取对应代币的价格 10 美元 返回的是 10* 10^8 
     */
    function getChainlinkDataFeedLatestAnswer(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        address aggregator = priceFeeds[token];
        require(aggregator != address(0), "Price feed not available");
        (,int256 answer,,,) = AggregatorV3Interface(aggregator).latestRoundData();
        return amount * uint256(answer);
    }

    // 允许升级
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
     * 卖家调用 ：需要传入 ： 拍卖的NFT地址，nft的tokenId(必须归卖家所有), 起拍价，拍卖持续时间
     * 自带参数： 卖家地址 msg.sender
     * @notice 创建一个新的拍卖
     * @param nftContract  拍卖的NFT的地址
     * @param tokenId  拍卖的NFT的ID
     * @param startPrice  起拍价
     * @param duration 拍卖持续时间
     */
    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 duration
    ) external {
        require(approvedNftContracts[nftContract], unicode"NFT 拍卖不被允许");
        require(duration >= minAuctionDuration, unicode"Duration 太短");

        // 转移NFT到合约 , tokenId 是nft合约（nftContract）下的某个nft的id ，必须归属卖家(msg.sender)
        IERC721(nftContract).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );

        // 计算开始和结束时间
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + duration;

        // 创建拍卖 并 存入map auctions
        auctions[nextAuctionId] = Auction({
            seller: msg.sender, // 发起创建请求的就是卖家
            nftContract: nftContract,
            tokenId: tokenId,
            startTime: startTime,
            endTime: endTime,
            startPrice: startPrice,
            highestBidder: address(0), // 初始地址0
            highestBid: 0,
            ended: false,
            highestBidToken: address(0), // 初始地址0
            highestBidAmount: 0
        });

        // 发送拍卖创建成功的日志
        emit AuctionCreated(
            nextAuctionId,
            nftContract,
            tokenId,
            msg.sender,
            startTime,
            endTime,
            startPrice
        );

        // 拍卖户id 自增一下
        nextAuctionId++;
    }

    /**
     * 买家调用
     * @notice
     * 自带参数
     * msg.sender ： 买家地址
     * msg.value ：Solidity中的payable函数在调用时，所有发送的ETH会自动存入合约的余额（无需显式代码）
     * token 代币的合约地址
     * @param auctionId  拍卖id
     */
    function placeBid(uint256 auctionId, address token, uint256 amount) external {
        Auction storage auction = auctions[auctionId];
        require(block.timestamp >= auction.startTime, "Auction not started");
        require(block.timestamp <= auction.endTime, "Auction ended");
        require(!auction.ended, "Auction already ended");
        require(token != address(0), "Invalid token");

        // 计算 USDT 计价的有效出价
        // 测试环境没有预言机，先注释
        // uint256 usdtAmount = getChainlinkDataFeedLatestAnswer(token, amount);
        uint256 usdtAmount = amount * 2 ;

        require(usdtAmount > auction.highestBid, "Bid too low");
        require(usdtAmount >= auction.startPrice, "Bid below start price");

        // 转移代币到合约
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        // 退还前一个出价者的代币
        if (auction.highestBidder != address(0)) {
            //  如果有前一个出价的,本合约(隐式代码) 退还 代币highestBidToken(代币的合约地址)，给 auction.highestBidder
            IERC20(auction.highestBidToken).transfer(
                auction.highestBidder, 
                auction.highestBidAmount
            );
        }
        // 更新最高出价
        auction.highestBidder = msg.sender;
        auction.highestBid = usdtAmount; 
        auction.highestBidToken = token;
        auction.highestBidAmount = amount;

        emit BidPlaced(auctionId, msg.sender, usdtAmount);
    }

    /**
     * 卖家和管理员调用
     * @notice 结束拍卖
     * @param auctionId ID of the auction to end
     */
    function endAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];

        require(block.timestamp >= auction.endTime, unicode"拍卖还没有结束");
        require(!auction.ended, unicode"拍卖已经结束");
        require(
            msg.sender == auction.seller || msg.sender == owner(),
            unicode"只有合约所有者和卖家可以结束拍卖"
        );

        auction.ended = true;

        if (auction.highestBidder != address(0)) {
            // 拍卖的钱给卖家
            uint256 platformFee = (auction.highestBid * platformFeePercentage) /100;
            uint256 sellerProceeds = auction.highestBid - platformFee;
            payable(auction.seller).transfer(sellerProceeds);
            // 结算手续费给合约（由合约所有者指定）
            payable(feeRecipient).transfer(platformFee);

            // 把NFT转给卖家
            IERC721(auction.nftContract).safeTransferFrom(
                address(this),
                auction.highestBidder,
                auction.tokenId
            );
            // 拍卖结束日志
            emit AuctionEnded(
                auctionId,
                auction.highestBidder,
                auction.highestBid
            );
        } else {
            // 没有人出价，nft 退还给 卖家
            IERC721(auction.nftContract).safeTransferFrom(
                address(this),
                auction.seller,
                auction.tokenId
            );
            // 取消拍卖日志
            emit AuctionCancelled(auctionId);
        }
    }

    /**
     * @notice 取消一个拍卖
     * @param auctionId ID of the auction to cancel
     */
    function cancelAuction(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];

        require(msg.sender == auction.seller, unicode"只有卖家可以取消拍卖");
        require(block.timestamp < auction.endTime, unicode"拍卖已经结束");
        require(auction.highestBidder == address(0), unicode"已投标");
        require(!auction.ended, unicode"拍卖已经结束");

        auction.ended = true;

        // nft 退还给 卖家
        IERC721(auction.nftContract).safeTransferFrom(
            address(this),
            auction.seller,
            auction.tokenId
        );
        // 拍卖取消日志
        emit AuctionCancelled(auctionId);
    }

    /**
     * @notice 只有管理员才能执行的操作: 允许一个NFT合约进行拍卖
     * @param nftContract Address of the NFT contract to approve
     */
    function approveNftContract(address nftContract) external onlyOwner {
        approvedNftContracts[nftContract] = true;
    }

    /**
     * @notice 有管理员才能执行的操作: 取消一个NFT合约进行拍卖
     * @param nftContract Address of the NFT contract to revoke
     */
    function revokeNftContract(address nftContract) external onlyOwner {
        approvedNftContracts[nftContract] = false;
    }

    /**
     * @notice 只有管理员才能执行的操作: 设置手续费百分比
     * @param newFeePercentage New fee percentage (1 = 1%)
     */
    function setPlatformFeePercentage(
        uint256 newFeePercentage
    ) external onlyOwner {
        require(newFeePercentage <= 10, "Fee too high"); // Max 10%
        platformFeePercentage = newFeePercentage;
    }

    /**
     * @notice 只有管理员才能执行的操作: 设置手续费首款地址
     * @param newFeeRecipient New fee recipient address
     */
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != address(0), "Invalid address");
        feeRecipient = newFeeRecipient;
    }

    /**
     * @notice 只有管理员才能执行的操作: 设置拍卖最短持续时间
     * @param newDuration New minimum duration in seconds
     */
    function setMinAuctionDuration(uint256 newDuration) external onlyOwner {
        minAuctionDuration = newDuration;
    }

    /**
     * 问题背景：当 NFT（ERC721）通过 safeTransferFrom() 转移到一个合约时，如果目标合约无法正确处理 NFT，可能导致资产永久锁定。
     * 解决方案：ERC721 标准要求目标合约必须实现 onERC721Received 并返回正确的魔法值
     * @notice ERC721 token receiver function
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     * 所有人调用
     * @notice 获取拍卖会信息
     * @param auctionId ID of the auction
     * @return Auction details
     */
    function getAuction(
        uint256 auctionId
    ) external view returns (Auction memory) {
        return auctions[auctionId];
    }

    /**
     *  所有人调用
     * @notice 拍卖是否进行中
     * @param auctionId ID of the auction
     * @return True if auction is active
     */
    function isAuctionActive(uint256 auctionId) external view returns (bool) {
        Auction storage auction = auctions[auctionId];
        return
            !auction.ended &&
            block.timestamp >= auction.startTime &&
            block.timestamp <= auction.endTime;
    }

    /**
     *  所有人调用
     * @notice Get the current highest bid for an auction
     * @param auctionId ID of the auction
     * @return Highest bid amount
     */
    function getHighestBid(uint256 auctionId) external view returns (uint256) {
        return auctions[auctionId].highestBid;
    }

    /**
     *  所有人调用
     * @notice 获取最高价
     * @param auctionId ID of the auction
     * @return Highest bidder address
     */
    function getHighestBidder(
        uint256 auctionId
    ) external view returns (address) {
        return auctions[auctionId].highestBidder;
    }
}
