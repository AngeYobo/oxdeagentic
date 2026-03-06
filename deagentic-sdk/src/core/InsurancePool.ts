import {
  PublicClient,
  WalletClient,
  Address,
  Hash,
  getContract,
} from 'viem';
import InsurancePoolABI from '../constants/abis/InsurancePool.json';

export enum ClaimStatus {
  UNAUTHORIZED = 0,
  AUTHORIZED = 1,
  CLAIMED = 2,
  EXPIRED = 3,
}

export class InsurancePoolClient {
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
      abi: InsurancePoolABI,
      client: this.publicClient,
    });
  }

  private getWriteContract() {
    if (!this.walletClient) {
      throw new Error('Wallet client required for write operations');
    }
    return getContract({
      address: this.address,
      abi: InsurancePoolABI,
      client: this.walletClient,
    });
  }

  async getPoolBalance(token: Address): Promise<bigint> {
    const contract = this.getReadContract();
    return await contract.read.poolBalance([token]) as bigint;
  }

  async getClaim(claimId: Hash): Promise<{
    payer: Address;
    provider: Address;
    token: Address;
    requestedAmount: bigint;
    authorizedAt: bigint;
    status: ClaimStatus;
  }> {
    const contract = this.getReadContract();
    const claim = await contract.read.claims([claimId]) as any;
    
    return {
      payer: claim.payer,
      provider: claim.provider,
      token: claim.token,
      requestedAmount: claim.requestedAmount,
      authorizedAt: claim.authorizedAt,
      status: claim.status as ClaimStatus,
    };
  }

  async getMaxPayerPayout(token: Address): Promise<bigint> {
    const contract = this.getReadContract();
    return await contract.read.MAX_PAYER_PAYOUT_PER_TOKEN([token]) as bigint;
  }

  async deposit(token: Address, amount: bigint): Promise<Hash> {
    const contract = this.getWriteContract();
    return await contract.write.deposit([token, amount]) as Hash;
  }

  async claim(intentId: Hash): Promise<Hash> {
    const contract = this.getWriteContract();
    return await contract.write.claim([intentId]) as Hash;
  }

  async expireClaim(claimId: Hash): Promise<Hash> {
    const contract = this.getWriteContract();
    return await contract.write.expireClaim([claimId]) as Hash;
  }
}
