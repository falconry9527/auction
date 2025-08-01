# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.js
```

依赖安装
```
npm install --save-dev hardhat
npx hardhat init
npx hardhat compile

npm install -D hardhat-deploy

npm install --save-dev  @nomiclabs/hardhat-ethers hardhat-deploy-ethers ethers

```