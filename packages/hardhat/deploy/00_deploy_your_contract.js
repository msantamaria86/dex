// deploy/00_deploy_your_contract.js

const { ethers } = require("hardhat");

const localChainId = "31337";

// const sleep = (ms) =>
//   new Promise((r) =>
//     setTimeout(() => {
//       console.log(`waited for ${(ms / 1000).toFixed(3)} seconds`);
//       r();
//     }, ms)
//   );

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  await deploy("Balloons", {
    // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
    from: deployer,
    // args: [ "Hello", ethers.utils.parseEther("1.5") ],
    log: true,
  });

  const balloons = await ethers.getContract("Balloons", deployer);

  await deploy("DEX", {
    // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
    from: deployer,
    args: [balloons.address],
    log: true,
    waitConfirmations: 5,
  });

  const dex = await ethers.getContract("DEX", deployer);

  // paste in your front-end address here to get 10 balloons on deploy:
  await balloons.transfer(
    "0xF6D84490707ed80Ea5A71D467f046c5568EC0284",
    "" + 10 * 10 ** 18
  );

  console.log(
    "Approving DEX (" + dex.address + ") to take Balloons from main account..."
  );
  await balloons.approve(dex.address, ethers.utils.parseEther("100"));
  console.log("INIT exchange...");
  await dex.init(ethers.utils.parseEther("5"), {
    value: ethers.utils.parseEther("5"),
    gasLimit: 200000,
  });
};
module.exports.tags = ["Balloons", "DEX"];
