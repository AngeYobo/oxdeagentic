"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateIntentId = generateIntentId;
exports.getNextNonce = getNextNonce;
const viem_1 = require("viem");
/**
 * Generate intent ID (deterministic, replay-resistant)
 *
 * Formula: keccak256(chainId, escrowAddress, payer, provider, token, amount, nonce)
 */
function generateIntentId(params) {
    return (0, viem_1.keccak256)((0, viem_1.encodePacked)(['uint256', 'address', 'address', 'address', 'address', 'uint256', 'uint256'], [
        BigInt(params.chainId),
        params.escrowAddress,
        params.payer,
        params.provider,
        params.token,
        params.amount,
        params.nonce,
    ]));
}
/**
 * Get next nonce for a payer
 * (In production, query from contract or maintain local counter)
 */
function getNextNonce() {
    return BigInt(Date.now());
}
