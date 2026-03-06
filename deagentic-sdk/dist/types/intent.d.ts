import { Address, Hash, Hex } from 'viem';
/**
 * Intent States (matching Solidity enum)
 */
export declare enum IntentState {
    NONE = 0,
    CREATED = 1,
    REVEALED = 2,
    DISPUTED = 3,
    SETTLED_PROVIDER = 4,
    SETTLED_PAYER = 5,
    SETTLED_SPLIT = 6,
    NO_REVEAL_FINALIZED = 7
}
/**
 * Intent flags
 */
export declare const IntentFlags: {
    readonly FAST_MODE: number;
    readonly ERC8004_USED: number;
};
/**
 * Intent creation parameters
 */
export interface CreateIntentParams {
    provider: Address;
    token: Address;
    amount: bigint;
    deadlineBlock: bigint;
    revealDeadline: bigint;
    fastMode: boolean;
    reputationMin: number;
    serviceHash: Hash;
    nonce: bigint;
    erc8004Attestation?: {
        attestationHash: Hash;
        signature: Hex;
    };
}
/**
 * Intent struct (matches Solidity)
 */
export interface Intent {
    payer: Address;
    provider: Address;
    token: Address;
    amount: bigint;
    deadlineBlock: bigint;
    revealDeadline: bigint;
    revealTimestamp: bigint;
    reputationMin: number;
    flags: number;
    state: IntentState;
    serviceHash: Hash;
    nonce: bigint;
}
/**
 * Reveal parameters
 */
export interface RevealParams {
    intentId: Hash;
    provider: Address;
    bond: bigint;
    salt: Hash;
}
/**
 * Service preimage for commit-reveal
 */
export interface ServicePreimage {
    description: string;
    deliverables: string[];
    metadata?: Record<string, unknown>;
}
