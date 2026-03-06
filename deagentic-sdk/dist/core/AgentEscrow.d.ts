import { PublicClient, WalletClient, Address, Hash } from 'viem';
import { CreateIntentParams, Intent, RevealParams } from '../types/intent';
import { OpenDisputeParams, Dispute, DisputeOutcome } from '../types/dispute';
import { FastCredit } from '../types/credit';
import { ServicePreimage } from '../utils/commitReveal';
/**
 * AgentEscrow client for interacting with the escrow contract
 */
export declare class AgentEscrowClient {
    private publicClient;
    private walletClient?;
    private address;
    private chainId;
    constructor(address: Address, publicClient: PublicClient, walletClient?: WalletClient);
    private getReadContract;
    private getWriteContract;
    getIntent(intentId: Hash): Promise<Intent>;
    getDispute(intentId: Hash): Promise<Dispute>;
    getCredit(intentId: Hash): Promise<FastCredit>;
    canUseCredit(payer: Address, token: Address, amount: bigint): Promise<boolean>;
    getFirstSeen(payer: Address): Promise<bigint>;
    createIntent(params: Omit<CreateIntentParams, 'serviceHash' | 'nonce'>, servicePreimage: ServicePreimage): Promise<{
        hash: Hash;
        intentId: Hash;
    }>;
    revealIntent(params: RevealParams): Promise<Hash>;
    settle(intentId: Hash): Promise<Hash>;
    finalizeNoReveal(intentId: Hash): Promise<Hash>;
    openDispute(params: OpenDisputeParams): Promise<Hash>;
    resolveDispute(intentId: Hash, outcome: DisputeOutcome, insuranceAmount: bigint): Promise<Hash>;
    executeDisputeTimeout(intentId: Hash): Promise<Hash>;
    withdrawCredit(intentId: Hash): Promise<Hash>;
    grantCredit(payer: Address, token: Address, amount: bigint): Promise<{
        hash: Hash;
        creditId: Hash;
    }>;
    expireCredit(creditId: Hash): Promise<Hash>;
    watchIntentCreated(callback: (event: {
        intentId: Hash;
        payer: Address;
        provider: Address;
        token: Address;
        amount: bigint;
    }) => void): import("viem").WatchContractEventReturnType;
}
