import { Address } from 'viem';

/**
 * Deployed contract addresses per chain
 */
export interface DeployedAddresses {
  agentEscrow: Address;
  stakeManager: Address;
  insurancePool: Address;
  reputationRegistry: Address;
  arbiterMultisig: Address;
}

/**
 * Contract addresses by chain ID
 */
export const DEPLOYED_ADDRESSES: Record<number, DeployedAddresses> = {
  // Base Mainnet (8453)
  8453: {
    agentEscrow: '0x0000000000000000000000000000000000000000', // TODO: Update after deploy
    stakeManager: '0x0000000000000000000000000000000000000000',
    insurancePool: '0x0000000000000000000000000000000000000000',
    reputationRegistry: '0x0000000000000000000000000000000000000000',
    arbiterMultisig: '0x0000000000000000000000000000000000000000',
  },
  
  // Base Sepolia Testnet (84532)
  84532: {
    agentEscrow: '0x0000000000000000000000000000000000000000', // TODO: Update after deploy
    stakeManager: '0x0000000000000000000000000000000000000000',
    insurancePool: '0x0000000000000000000000000000000000000000',
    reputationRegistry: '0x0000000000000000000000000000000000000000',
    arbiterMultisig: '0x0000000000000000000000000000000000000000',
  },
  
  // Localhost (31337) for testing
  31337: {
    agentEscrow: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
    stakeManager: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
    insurancePool: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
    reputationRegistry: '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9',
    arbiterMultisig: '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9',
  },
};

/**
 * Get deployed addresses for a chain
 */
export function getAddresses(chainId: number): DeployedAddresses {
  const addresses = DEPLOYED_ADDRESSES[chainId];
  if (!addresses) {
    throw new Error(`No deployed addresses for chain ${chainId}`);
  }
  return addresses;
}
