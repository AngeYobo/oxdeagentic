// Core clients
export { AgentEscrowClient } from './core/AgentEscrow';
export { StakeManagerClient } from './core/StakeManager';
export { InsurancePoolClient } from './core/InsurancePool';
export { ReputationClient } from './core/Reputation';

// Types
export * from './types/intent';
export * from './types/dispute';
export * from './types/credit';

// Utils
export * from './utils/commitReveal';
export * from './utils/intentId';

// Export ServicePreimage type explicitly
export type { ServicePreimage } from './utils/commitReveal';

// Constants
export { DEPLOYED_ADDRESSES, getAddresses } from './constants/addresses';

// Re-export viem types for convenience
export type { Address, Hash, Hex, PublicClient, WalletClient } from 'viem';
