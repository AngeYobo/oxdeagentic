import { Address, Hash } from 'viem';

/**
 * Credit status (FastMode credits)
 */
export enum CreditStatus {
  NONE = 0,
  CREATED = 1,
  FROZEN = 2,
  ADJUSTED = 3,
  VOIDED = 4,
  WITHDRAWN = 5,
}

/**
 * Fast credit struct
 */
export interface FastCredit {
  token: Address;
  provider: Address;
  amount: bigint;
  createdAt: bigint;
  unlockAt: bigint;
  status: CreditStatus;
}
