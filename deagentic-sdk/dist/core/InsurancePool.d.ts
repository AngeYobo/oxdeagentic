import { PublicClient, WalletClient, Address, Hash } from 'viem';
export declare enum ClaimStatus {
    UNAUTHORIZED = 0,
    AUTHORIZED = 1,
    CLAIMED = 2,
    EXPIRED = 3
}
export declare class InsurancePoolClient {
    private publicClient;
    private walletClient?;
    private address;
    constructor(address: Address, publicClient: PublicClient, walletClient?: WalletClient);
    private getReadContract;
    private getWriteContract;
    getPoolBalance(token: Address): Promise<bigint>;
    getClaim(claimId: Hash): Promise<{
        payer: Address;
        provider: Address;
        token: Address;
        requestedAmount: bigint;
        authorizedAt: bigint;
        status: ClaimStatus;
    }>;
    getMaxPayerPayout(token: Address): Promise<bigint>;
    deposit(token: Address, amount: bigint): Promise<Hash>;
    claim(intentId: Hash): Promise<Hash>;
    expireClaim(claimId: Hash): Promise<Hash>;
}
