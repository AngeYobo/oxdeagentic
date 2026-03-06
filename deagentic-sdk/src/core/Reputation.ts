import {
  PublicClient,
  WalletClient,
  Address,
  getContract,
} from 'viem';
import ReputationRegistryABI from '../constants/abis/ReputationRegistry.json';

/**
 * ReputationRegistry client for reputation queries
 */
export class ReputationClient {
  private publicClient: PublicClient;
  private walletClient?: WalletClient;
  private address: Address;

  constructor(
    address: Address,
    publicClient: PublicClient,
    walletClient?: WalletClient,
  ) {
    this.address = address;
    this.publicClient = publicClient;
    this.walletClient = walletClient;
  }

  private getReadContract() {
    return getContract({
      address: this.address,
      abi: ReputationRegistryABI,
      client: this.publicClient,
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // READ METHODS
  // ═══════════════════════════════════════════════════════════════

  async getScore(provider: Address): Promise<number> {
    const contract = this.getReadContract();
    const score = await contract.read.scores([provider]) as bigint;
    return Number(score);
  }

  async getCurrentEpoch(): Promise<bigint> {
    const contract = this.getReadContract();
    return await contract.read.getCurrentEpoch() as bigint;
  }

  async getCounterpartyGains(
    provider: Address,
    payer: Address,
    epochStart: bigint,
  ): Promise<bigint> {
    const contract = this.getReadContract();
    return await contract.read.counterpartyGains([provider, payer, epochStart]) as bigint;
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════

  async meetsThreshold(provider: Address, threshold: number): Promise<boolean> {
    const score = await this.getScore(provider);
    return score >= threshold;
  }

  async getReputationPercentage(provider: Address): Promise<number> {
    const score = await this.getScore(provider);
    return (score / 1000) * 100;
  }
}
