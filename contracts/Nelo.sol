// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Nelo
 * @notice Scalable custody/escrow contract for ERC20 tokens (and native ETH as wrapped token).
 * - Optimized for many users (minimal storage)
 * - Uses SafeERC20 and supports EIP-2612 permits
 * - Role-based operator/admin separation
 * - Emits rich events for off-chain agents
 *
 * IMPORTANT: This contract intentionally does NOT perform fiat/card issuance on-chain.
 * Off-chain backend listens to events and performs KYC, conversion and card issuance.
 */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Nelo is AccessControl, ReentrancyGuard, Multicall {
    using SafeERC20 for IERC20;
    using Address for address;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    // ADMIN (DEFAULT_ADMIN_ROLE) should be a multisig in production

    // user => token => amount
    mapping(address => mapping(address => uint256)) private _balances;

    // token whitelist - only whitelisted tokens may be deposited
    mapping(address => bool) public tokenWhitelisted;

    // Optional: designate a wrapped native token (WETH) address for native-ETH flows
    address public immutable wrappedNative;

    // Events
    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount, address indexed to);
    event TokenWhitelisted(address indexed token, bool indexed allowed);
    event TransferToCustodian(address indexed user, address indexed token, uint256 amount, address indexed custodian);
    event EmergencyRecovered(address indexed token, address indexed to, uint256 amount);

    // Constructor: pass the wrapped native token (WETH) address or zero if not used
    constructor(address _wrappedNative, address admin) {
        require(admin != address(0), "admin zero");
        wrappedNative = _wrappedNative;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // -------------------------
    // Deposits
    // -------------------------

    /**
     * @notice Deposit ERC20 tokens into contract custody.
     * @param token The ERC20 token address (must be whitelisted).
     * @param amount Amount to deposit.
     */
    function deposit(address token, uint256 amount) external nonReentrant {
        require(amount > 0, "Zero amount");
        require(tokenWhitelisted[token], "Token not allowed");
        // TransferFrom using SafeERC20 for fee-on-transfer support and safe checks
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _balances[msg.sender][token] += amount;
        emit Deposited(msg.sender, token, amount);
    }

    /**
     * @notice Deposit using permit (EIP-2612) to avoid separate approve tx.
     * @param token Token supporting permit.
     * @param amount Amount to deposit.
     * @param deadline Permit deadline.
     * @param v,r,s Permit signature components.
     */
    function depositWithPermit(
        IERC20Permit token,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        address tokenAddr = address(token);
        require(amount > 0, "Zero amount");
        require(tokenWhitelisted[tokenAddr], "Token not allowed");

        // call permit to approve this contract
        token.permit(msg.sender, address(this), amount, deadline, v, r, s);

        // transfer
        IERC20(tokenAddr).safeTransferFrom(msg.sender, address(this), amount);
        _balances[msg.sender][tokenAddr] += amount;
        emit Deposited(msg.sender, tokenAddr, amount);
    }

    // -------------------------
    // Withdrawals (pull)
    // -------------------------

    /**
     * @notice Withdraw user's tokens from custody to their address.
     * @param token Token address.
     * @param amount Amount to withdraw.
     * @param to Recipient address.
     */
    function withdraw(address token, uint256 amount, address to) external nonReentrant {
        require(amount > 0, "Zero amount");
        require(to != address(0), "Zero to");
        uint256 bal = _balances[msg.sender][token];
        require(bal >= amount, "Insufficient balance");

        // Effects
        _balances[msg.sender][token] = bal - amount;

        // Interactions
        IERC20(token).safeTransfer(to, amount);

        emit Withdrawn(msg.sender, token, amount, to);
    }

    /**
     * @notice View user's balance for a token.
     */
    function balanceOf(address user, address token) external view returns (uint256) {
        return _balances[user][token];
    }

    // -------------------------
    // Operator flows (for custodial conversion)
    // -------------------------

    /**
     * @notice Operator transfers user's token to a custodian (off-chain provider).
     * This is intended for off-chain fiat conversion. The operator must be authorized.
     * @param user The owner whose balance is used.
     * @param token Token address.
     * @param amount Amount to transfer.
     * @param custodian Address of custodial partner.
     */
    function transferToCustodian(address user, address token, uint256 amount, address custodian) external nonReentrant onlyRole(OPERATOR_ROLE) {
        require(amount > 0, "Zero amount");
        require(custodian != address(0), "Invalid custodian");
        uint256 bal = _balances[user][token];
        require(bal >= amount, "Insufficient user balance");

        // Effects
        _balances[user][token] = bal - amount;

        // Interactions
        IERC20(token).safeTransfer(custodian, amount);

        emit TransferToCustodian(user, token, amount, custodian);
    }

    // -------------------------
    // Admin: token whitelist
    // -------------------------
    function setTokenWhitelist(address token, bool allowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenWhitelisted[token] = allowed;
        emit TokenWhitelisted(token, allowed);
    }

    // -------------------------
    // Emergency / recovery (admin only)
    // -------------------------

    /**
     * @notice Emergency recovery: move tokens mistakenly sent to this contract (or drained in admin scenario)
     * Admin-only; in production make sure ADMIN is a multisig and use governance procedure.
     */
    function emergencyRecoverERC20(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "Invalid to");
        IERC20(token).safeTransfer(to, amount);
        emit EmergencyRecovered(token, to, amount);
    }

    // -------------------------
    // Convenience: batch queries (off-chain gasless)
    // -------------------------

    /**
     * @notice Batch view helper - used off-chain via eth_call to reduce RPC requests.
     * This is view-only and does not cost gas for off-chain calls.
     */
    function batchBalances(address[] calldata users, address[] calldata tokens) external view returns (uint256[] memory) {
        require(users.length > 0 && tokens.length > 0, "Empty arrays");
        uint256[] memory out = new uint256[](users.length * tokens.length);
        uint256 k = 0;
        for (uint256 i = 0; i < users.length; ++i) {
            for (uint256 j = 0; j < tokens.length; ++j) {
                out[k++] = _balances[users[i]][tokens[j]];
            }
        }
        return out;
    }
}
