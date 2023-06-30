const  hre  = require("hardhat");

async function main() {
  const addr = "0x4aDa8467cb6Ca77eb196504282091010606ee769";
  const CPAMM = await hre.ethers.getContractFactory("CPAMM");
  const cpamm = await CPAMM.deploy(addr);
  await cpamm.waitForDeployment();

  console.log(
    `cpamm deployed to ${cpamm.target}`
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
