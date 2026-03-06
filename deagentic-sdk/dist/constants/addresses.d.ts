import { Address } from 'viem';
/**
 * Deployed contract addresses per chain
 */
export interface DeployedAddresses {
    agentEscrow: Address;
    stakeManager: Address;
    insurancePool: Address;
    reputationRegistry: Address;
    arbiterMultisig: Address;
}
/**
 * Contract addresses by chain ID
 */
export declare const DEPLOYED_ADDRESSES: Record<number, DeployedAddresses>;
/**
 * Get deployed addresses for a chain
 */
export declare function getAddresses(chainId: number): DeployedAddresses;
