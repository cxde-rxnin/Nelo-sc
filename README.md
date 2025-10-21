# Nelo Smart Contract Project

## Summary

Nelo is a scalable custody/escrow smart contract for ERC20 tokens and native ETH (as a wrapped token). It is designed for efficient management of user balances, secure deposits and withdrawals, and role-based access control. Key features include:
- Support for ERC20 tokens and native ETH (via a wrapped token address)
- Role-based admin/operator separation using OpenZeppelin AccessControl
- Token whitelisting for secure deposits
- SafeERC20 and EIP-2612 permit support
- Rich event emission for off-chain agents
- Optimized for many users with minimal storage

**Note:** Fiat/card issuance is handled off-chain. The contract emits events for backend agents to process KYC, conversion, and card issuance.

## How to Use

### Prerequisites
- Node.js and npm installed
- Hardhat and dependencies installed (`npm install`)
- Base Sepolia testnet ETH in your deployment wallet

### Environment Setup
1. Copy `.env.example` to `.env` and fill in your values:
   ```
   BASE_SEPOLIA_URL=your_rpc_url
   PRIVATE_KEY=your_private_key
   WRAPPED_NATIVE_ADDRESS=0x0000000000000000000000000000000000000000 # or WETH address
   ADMIN_ADDRESS=your_public_address
   ```
2. Install dependencies:
   ```
   npm install
   ```

### Deployment
Deploy the contract to Base Sepolia:
```sh
npx hardhat ignition deploy ./ignition/modules/deploy.ts --network baseSepolia
```

### Interacting with the Contract
- **Deposit ERC20 tokens:**
  Call `deposit(token, amount)` to deposit whitelisted tokens.
- **Deposit with permit:**
  Call `depositWithPermit(token, amount, deadline, v, r, s)` for EIP-2612 tokens.
- **Withdraw tokens:**
  Call `withdraw(token, amount, to)` to withdraw your tokens.
- **Whitelist tokens:**
  Admin can call `setTokenWhitelisted(token, allowed)` to manage allowed tokens.

### Events
- `Deposited(user, token, amount)`
- `Withdrawn(user, token, amount, to)`
- `TokenWhitelisted(token, allowed)`
- `TransferToCustodian(user, token, amount, custodian)`
- `EmergencyRecovered(token, to, amount)`

### Security
- Only whitelisted tokens can be deposited.
- Admin and operator roles are separated for security.
- All critical actions emit events for off-chain monitoring.

## Development
- Contract source: `contracts/Nelo.sol`
- Deployment module: `ignition/modules/deploy.ts`
- Tests: `test/`

## License
MIT
