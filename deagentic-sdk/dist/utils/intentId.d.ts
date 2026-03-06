import { Hash, Address } from 'viem';
/**
 * Generate intent ID (deterministic, replay-resistant)
 *
 * Formula: keccak256(chainId, escrowAddress, payer, provider, token, amount, nonce)
 */
export declare function generateIntentId(params: {
    chainId: number;
    escrowAddress: Address;
    payer: Address;
    provider: Address;
    token: Address;
    amount: bigint;
    nonce: bigint;
}): Hash;
/**
 * Get next nonce for a payer
 * (In production, query from contract or maintain local counter)
 */
export declare function getNextNonce(): bigint;
