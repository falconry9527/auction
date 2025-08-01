// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract NftAuction is 
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    struct Auction {
        uint256 tokenId;
        address seller;
        uint256 startPrice;
        uint256 startTime;
        uint256 endTime;
        address highestBidder;
        uint256 highestBid;
        bool ended;
    }

    uint256 private _nextTokenId;
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => string) private _tokenURIs;

    event AuctionCreated(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 startPrice,
        uint256 startTime,
        uint256 endTime
    );

    event BidPlaced(
        uint256 indexed tokenId,
        address indexed bidder,
        uint256 amount
    );

    event AuctionEnded(
        uint256 indexed tokenId,
        address indexed winner,
        uint256 amount
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC721_init("AuctionNFT", "ANFT");
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    // 创建NFT并开始拍卖
    function createAuction(
        string memory tokenURI,
        uint256 startPrice,
        uint256 durationInHours
    ) external {
        uint256 tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenURI);

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + durationInHours * 1 hours;

        auctions[tokenId] = Auction({
            tokenId: tokenId,
            seller: msg.sender,
            startPrice: startPrice,
            startTime: startTime,
            endTime: endTime,
            highestBidder: address(0),
            highestBid: startPrice,
            ended: false
        });

        emit AuctionCreated(tokenId, msg.sender, startPrice, startTime, endTime);
    }

    // 出价函数
    function placeBid(uint256 tokenId) external payable virtual nonReentrant {
        Auction storage auction = auctions[tokenId];
        require(block.timestamp >= auction.startTime, "Auction not started");
        require(block.timestamp <= auction.endTime, "Auction ended");
        require(msg.value > auction.highestBid, "Bid too low");
        require(msg.sender != auction.seller, "Seller cannot bid");

        // 退还前一个最高出价者的资金
        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.highestBid);
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        emit BidPlaced(tokenId, msg.sender, msg.value);
    }

    // 结束拍卖并分配NFT和资金
    function endAuction(uint256 tokenId) external nonReentrant {
        Auction storage auction = auctions[tokenId];
        require(block.timestamp >= auction.endTime, "Auction not ended");
        require(!auction.ended, "Auction already ended");
        require(
            msg.sender == auction.seller || msg.sender == owner(),
            "Only seller or owner can end auction"
        );

        auction.ended = true;

        if (auction.highestBidder != address(0)) {
            // 转移NFT给最高出价者
            _transfer(auction.seller, auction.highestBidder, tokenId);
            
            // 转移资金给卖家（扣除1%平台费用）
            uint256 platformFee = auction.highestBid / 100;
            uint256 sellerProceeds = auction.highestBid - platformFee;
            
            payable(auction.seller).transfer(sellerProceeds);
            payable(owner()).transfer(platformFee);
        } else {
            // 无人出价，NFT仍归卖家所有
            _transfer(auction.seller, auction.seller, tokenId);
        }

        emit AuctionEnded(tokenId, auction.highestBidder, auction.highestBid);
    }

    // 查询拍卖信息
    function getAuction(uint256 tokenId) external view returns (Auction memory) {
        return auctions[tokenId];
    }

    // 设置Token URI（内部函数）
    function _setTokenURI(uint256 tokenId, string memory tokenURI) internal {
        _tokenURIs[tokenId] = tokenURI;
    }

    // 获取Token URI
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return _tokenURIs[tokenId];
    }
}