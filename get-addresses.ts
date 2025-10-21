// Run this script with: npx ts-node get-addresses.ts
require("dotenv").config();
import { Wallet } from "ethers";

// Get private key from env
const privateKey = process.env.PRIVATE_KEY;
if (!privateKey) {
  throw new Error("PRIVATE_KEY not set in .env");
}

const wallet = new Wallet(privateKey);
console.log("Your public address:", wallet.address);

// For Base Sepolia, there is no official WETH yet. Use zero address as placeholder.
console.log("Wrapped native address (placeholder): 0x0000000000000000000000000000000000000000");
