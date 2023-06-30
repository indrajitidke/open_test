

const hre = require("hardhat");

async function main() {

  const tokenizedShares = await hre.ethers.deployContract("TokenizedShares");

  await tokenizedShares.waitForDeployment();
  const ownerAddress = await tokenizedShares.owner();
  console.log("Contract Owner Address:", ownerAddress);

  console.log(
    `tokenizedShares deployed to ${tokenizedShares.target} `
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
