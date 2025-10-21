import { ethers } from "hardhat";

async function main() {
  const CryptoWallet = await ethers.getContractFactory("CryptoWallet");
  const wallet = await CryptoWallet.deploy();

  await wallet.waitForDeployment();

  console.log("✅ CryptoWallet deployed at:", await wallet.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
