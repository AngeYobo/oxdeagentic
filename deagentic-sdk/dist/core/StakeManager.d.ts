import { PublicClient, WalletClient, Address, Hash } from 'viem';
export declare class StakeManagerClient {
    private publicClient;
    private walletClient?;
    private address;
    constructor(address: Address, publicClient: PublicClient, walletClient?: WalletClient);
    private getReadContract;
    private getWriteContract;
    getTotalStake(provider: Address, token: Address): Promise<bigint>;
    getLockedStake(provider: Address, token: Address): Promise<bigint>;
    getAvailableStake(provider: Address, token: Address): Promise<bigint>;
    getIntentLock(intentId: Hash): Promise<{
        provider: Address;
        token: Address;
        amount: bigint;
        active: boolean;
    }>;
    depositStake(token: Address, amount: bigint): Promise<Hash>;
    withdrawStake(token: Address, amount: bigint): Promise<Hash>;
    hasSufficientStake(provider: Address, token: Address, required: bigint): Promise<boolean>;
    getStakeUtilization(provider: Address, token: Address): Promise<number>;
}
