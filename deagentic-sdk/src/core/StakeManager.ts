import {
  PublicClient,
  WalletClient,
  Address,
  Hash,
  getContract,
} from 'viem';
import StakeManagerABI from '../constants/abis/StakeManager.json';

export class StakeManagerClient {
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
      abi: StakeManagerABI,
      client: this.publicClient,
    });
  }

  private getWriteContract() {
    if (!this.walletClient) {
      throw new Error('Wallet client required for write operations');
    }
    return getContract({
      address: this.address,
      abi: StakeManagerABI,
      client: this.walletClient,
    });
  }

  async getTotalStake(provider: Address, token: Address): Promise<bigint> {
    const contract = this.getReadContract();
    return await contract.read.totalStake([provider, token]) as bigint;
  }

  async getLockedStake(provider: Address, token: Address): Promise<bigint> {
    const contract = this.getReadContract();
    return await contract.read.lockedStake([provider, token]) as bigint;
  }

  async getAvailableStake(provider: Address, token: Address): Promise<bigint> {
    const contract = this.getReadContract();
    return await contract.read.availableStake([provider, token]) as bigint;
  }

  async getIntentLock(intentId: Hash): Promise<{
    provider: Address;
    token: Address;
    amount: bigint;
    active: boolean;
  }> {
    const contract = this.getReadContract();
    const lock = await contract.read.intentLocks([intentId]) as any;
    
    return {
      provider: lock.provider,
      token: lock.token,
      amount: lock.amount,
      active: lock.active,
    };
  }

  async depositStake(token: Address, amount: bigint): Promise<Hash> {
    const contract = this.getWriteContract();
    return await contract.write.depositStake([token, amount]) as Hash;
  }

  async withdrawStake(token: Address, amount: bigint): Promise<Hash> {
    const contract = this.getWriteContract();
    return await contract.write.withdrawStake([token, amount]) as Hash;
  }

  async hasSufficientStake(
    provider: Address,
    token: Address,
    required: bigint,
  ): Promise<boolean> {
    const available = await this.getAvailableStake(provider, token);
    return available >= required;
  }

  async getStakeUtilization(provider: Address, token: Address): Promise<number> {
    const total = await this.getTotalStake(provider, token);
    if (total === 0n) return 0;
    
    const locked = await this.getLockedStake(provider, token);
    return Number((locked * 10000n) / total) / 100;
  }
}
