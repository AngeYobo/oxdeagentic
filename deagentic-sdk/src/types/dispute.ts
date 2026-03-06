import { Address, Hash } from 'viem';

/**
 * Dispute status (matching Solidity enum)
 */
export enum DisputeStatus {
  NONE = 0,
  OPEN = 1,
  RESOLVED_PAYER = 2,
  RESOLVED_PROVIDER = 3,
  RESOLVED_SPLIT = 4,
  TIMEOUT_SPLIT = 5,
}

/**
 * Dispute outcome for resolution
 */
export enum DisputeOutcome {
  PAYER_WIN = 0,
  PROVIDER_WIN = 1,
  SPLIT_50_50 = 2,
}

/**
 * Dispute struct (matches Solidity)
 */
export interface Dispute {
  status: DisputeStatus;
  openedAt: bigint;
  evidenceHash: Hash;
  bondAmount: bigint;
}

/**
 * Parameters for opening a dispute
 */
export interface OpenDisputeParams {
  intentId: Hash;
  evidenceHash: Hash;
  evidence: {
    description: string;
    proofUrls?: string[];
    metadata?: Record<string, unknown>;
  };
}

/**
 * Parameters for resolving a dispute (arbiter only)
 */
export interface ResolveDisputeParams {
  intentId: Hash;
  outcome: DisputeOutcome;
  insuranceAmount: bigint;
}
