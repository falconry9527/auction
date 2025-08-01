# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

hardhat 基础命令
```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.js
```

hardhat 依赖安装
```
npm install --save-dev hardhat
npm install -D hardhat-deploy
npm install  @openzeppelin/hardhat-upgrades 
npm install @chainlink/contracts
```

hardhat 常用命令
```
npm cache clean --force
npm config set registry https://mirrors.cloud.tencent.com/npm/

```

部署和升级脚本
```
npx hardhat clean && npx hardhat compile

npx hardhat deploy   --tags deployNftAuction --network sepolia 
npx hardhat deploy   --tags upgradeNftAuction --network sepolia 

```

