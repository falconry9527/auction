// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestERC20 is ERC20, ERC20Permit, Ownable {
    constructor() ERC20("MyToken", "MTK") ERC20Permit("MyToken") Ownable(msg.sender) {
        _mint(msg.sender, 100000 * 10 ** 18);
    }

    function mint() external  {
        _mint(msg.sender, 10 * 10 ** 10);
    }


    // fallback 函数 则更通用，可以处理任意不存在的函数调用。
    // 如果没有 receive 函数，而合约接收以太币，它也会处理以太币的接收。
    event FallbackCalled(address sender, uint amount);
    // 当调用不存在的函数时触发
    fallback() external payable {
        emit FallbackCalled(msg.sender, msg.value);
    }
}