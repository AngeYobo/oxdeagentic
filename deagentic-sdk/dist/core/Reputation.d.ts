import { PublicClient, WalletClient, Address } from 'viem';
/**
 * ReputationRegistry client for reputation queries
 */
export declare class ReputationClient {
    private publicClient;
    private walletClient?;
    private address;
    constructor(address: Address, publicClient: PublicClient, walletClient?: WalletClient);
    private getReadContract;
    getScore(provider: Address): Promise<number>;
    getCurrentEpoch(): Promise<bigint>;
    getCounterpartyGains(provider: Address, payer: Address, epochStart: bigint): Promise<bigint>;
    meetsThreshold(provider: Address, threshold: number): Promise<boolean>;
    getReputationPercentage(provider: Address): Promise<number>;
}
