import {
  PublicClient,
  WalletClient,
  Address,
  Hash,
  Hex,
  getContract,
} from 'viem';
import { CreateIntentParams, Intent, IntentState, RevealParams } from '../types/intent';
import { OpenDisputeParams, Dispute, DisputeOutcome } from '../types/dispute';
import { FastCredit } from '../types/credit';
import { generateIntentId, getNextNonce } from '../utils/intentId';
import { generateServiceHash, encodeServicePreimage, ServicePreimage } from '../utils/commitReveal';
import AgentEscrowABI from '../constants/abis/AgentEscrow.json';

/**
 * AgentEscrow client for interacting with the escrow contract
 */
export class AgentEscrowClient {
  private publicClient: PublicClient;
  private walletClient?: WalletClient;
  private address: Address;
  private chainId: number;

  constructor(
    address: Address,
    publicClient: PublicClient,
    walletClient?: WalletClient,
  ) {
    this.address = address;
    this.publicClient = publicClient;
    this.walletClient = walletClient;
    this.chainId = publicClient.chain!.id;
  }

  private getReadContract() {
    return getContract({
      address: this.address,
      abi: AgentEscrowABI,
      client: this.publicClient,
    });
  }

  private getWriteContract() {
    if (!this.walletClient) {
      throw new Error('Wallet client required for write operations');
    }
    return getContract({
      address: this.address,
      abi: AgentEscrowABI,
      client: this.walletClient,
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // READ METHODS
  // ═══════════════════════════════════════════════════════════════

  async getIntent(intentId: Hash): Promise<Intent> {
    const contract = this.getReadContract();
    const intent = await contract.read.getIntent([intentId]) as any;
    
    return {
      payer: intent.payer,
      provider: intent.provider,
      token: intent.token,
      amount: intent.amount,
      deadlineBlock: intent.deadlineBlock,
      revealDeadline: intent.revealDeadline,
      revealTimestamp: intent.revealTimestamp,
      reputationMin: intent.reputationMin,
      flags: intent.flags,
      state: intent.state as IntentState,
      serviceHash: intent.serviceHash,
      nonce: intent.nonce,
    };
  }

  async getDispute(intentId: Hash): Promise<Dispute> {
    const contract = this.getReadContract();
    const dispute = await contract.read.getDispute([intentId]) as any;
    
    return {
      status: dispute.status,
      openedAt: dispute.openedAt,
      evidenceHash: dispute.evidenceHash,
      bondAmount: dispute.bondAmount,
    };
  }

  async getCredit(intentId: Hash): Promise<FastCredit> {
    const contract = this.getReadContract();
    const credit = await contract.read.getCredit([intentId]) as any;
    
    return {
      token: credit.token,
      provider: credit.provider,
      amount: credit.amount,
      createdAt: credit.createdAt,
      unlockAt: credit.unlockAt,
      status: credit.status,
    };
  }

  async canUseCredit(
    payer: Address,
    token: Address,
    amount: bigint,
  ): Promise<boolean> {
    const contract = this.getReadContract();
    return await contract.read.canUseCredit([payer, token, amount]) as boolean;
  }

  async getFirstSeen(payer: Address): Promise<bigint> {
    const contract = this.getReadContract();
    return await contract.read.firstSeen([payer]) as bigint;
  }

  // ═══════════════════════════════════════════════════════════════
  // WRITE METHODS - Intent Lifecycle
  // ═══════════════════════════════════════════════════════════════

  async createIntent(
    params: Omit<CreateIntentParams, 'serviceHash' | 'nonce'>,
    servicePreimage: ServicePreimage,
  ): Promise<{ hash: Hash; intentId: Hash }> {
    const contract = this.getWriteContract();

    const nonce = getNextNonce();
    const intentId = generateIntentId({
      chainId: this.chainId,
      escrowAddress: this.address,
      payer: this.walletClient!.account!.address,
      provider: params.provider,
      token: params.token,
      amount: params.amount,
      nonce,
    });

    const preimageBytes = encodeServicePreimage(servicePreimage);
    const serviceHash = generateServiceHash({
      chainId: this.chainId,
      escrowAddress: this.address,
      intentId,
      payer: this.walletClient!.account!.address,
      provider: params.provider,
      token: params.token,
      amount: params.amount,
      preimage: preimageBytes,
    });

    const hash = await contract.write.createIntent([
      params.provider,
      params.token,
      params.amount,
      params.deadlineBlock,
      params.revealDeadline,
      params.fastMode,
      params.reputationMin,
      serviceHash,
      nonce,
      params.erc8004Attestation?.attestationHash || '0x0000000000000000000000000000000000000000000000000000000000000000',
      params.erc8004Attestation?.signature || '0x',
    ]) as Hash;

    return { hash, intentId };
  }

  async revealIntent(params: RevealParams): Promise<Hash> {
    const contract = this.getWriteContract();
    return await contract.write.revealIntent([
      params.intentId,
      params.provider,
      params.bond,
      params.salt,
    ]) as Hash;
  }

  async settle(intentId: Hash): Promise<Hash> {
    const contract = this.getWriteContract();
    return await contract.write.settle([intentId]) as Hash;
  }

  async finalizeNoReveal(intentId: Hash): Promise<Hash> {
    const contract = this.getWriteContract();
    return await contract.write.finalizeNoReveal([intentId]) as Hash;
  }

  async openDispute(params: OpenDisputeParams): Promise<Hash> {
    const contract = this.getWriteContract();
    return await contract.write.openDispute([
      params.intentId,
      params.evidenceHash,
    ]) as Hash;
  }

  async resolveDispute(
    intentId: Hash,
    outcome: DisputeOutcome,
    insuranceAmount: bigint,
  ): Promise<Hash> {
    const contract = this.getWriteContract();
    return await contract.write.resolveDispute([
      intentId,
      outcome,
      insuranceAmount,
    ]) as Hash;
  }

  async executeDisputeTimeout(intentId: Hash): Promise<Hash> {
    const contract = this.getWriteContract();
    return await contract.write.executeDisputeTimeout([intentId]) as Hash;
  }

  async withdrawCredit(intentId: Hash): Promise<Hash> {
    const contract = this.getWriteContract();
    return await contract.write.withdrawCredit([intentId]) as Hash;
  }

  async grantCredit(
    payer: Address,
    token: Address,
    amount: bigint,
  ): Promise<{ hash: Hash; creditId: Hash }> {
    const contract = this.getWriteContract();
    const hash = await contract.write.grantCredit([payer, token, amount]) as Hash;
    
    const creditId = generateIntentId({
      chainId: this.chainId,
      escrowAddress: this.address,
      payer,
      provider: payer,
      token,
      amount,
      nonce: 0n,
    });

    return { hash, creditId };
  }

  async expireCredit(creditId: Hash): Promise<Hash> {
    const contract = this.getWriteContract();
    return await contract.write.expireCredit([creditId]) as Hash;
  }

  watchIntentCreated(
    callback: (event: {
      intentId: Hash;
      payer: Address;
      provider: Address;
      token: Address;
      amount: bigint;
    }) => void,
  ) {
    return this.publicClient.watchContractEvent({
      address: this.address,
      abi: AgentEscrowABI as any,
      eventName: 'IntentCreated',
      onLogs: (logs: any[]) => {
        logs.forEach((log: any) => {
          callback({
            intentId: log.args.intentId!,
            payer: log.args.payer!,
            provider: log.args.provider!,
            token: log.args.token!,
            amount: log.args.amount!,
          });
        });
      },
    });
  }
}
