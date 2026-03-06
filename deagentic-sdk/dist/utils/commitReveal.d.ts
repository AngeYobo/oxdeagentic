import { Hash, Address, Hex } from 'viem';
/**
 * Domain separator for service hash
 */
export declare const SERVICE_HASH_DOMAIN = "DEAI_SERVICE_V1";
/**
 * Service preimage structure
 */
export interface ServicePreimage {
    description: string;
    deliverables: string[];
    metadata?: Record<string, unknown>;
}
/**
 * Generate service hash for commit-reveal
 *
 * @param params Service hash parameters
 * @returns Service hash
 */
export declare function generateServiceHash(params: {
    chainId: number;
    escrowAddress: Address;
    intentId: Hash;
    payer: Address;
    provider: Address;
    token: Address;
    amount: bigint;
    preimage: string | Hex;
}): Hash;
/**
 * Generate random salt for commit-reveal
 */
export declare function generateSalt(): Hash;
/**
 * Encode service preimage to bytes
 */
export declare function encodeServicePreimage(preimage: ServicePreimage): Hex;
/**
 * Decode service preimage from bytes
 */
export declare function decodeServicePreimage(encoded: Hex): ServicePreimage;
