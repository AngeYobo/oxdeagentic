# @deagentic/sdk

TypeScript SDK for the DeAgentic Protocol - Deterministic Settlement Layer for AI Agents.

## Installation
```bash
npm install @deagentic/sdk
# or
pnpm add @deagentic/sdk
# or
yarn add @deagentic/sdk
```

## Quick Start
```typescript
import { AgentEscrowClient, generateServiceHash } from '@deagentic/sdk';
import { createPublicClient, createWalletClient, http } from 'viem';
import { base } from 'viem/chains';

// Setup clients
const publicClient = createPublicClient({
  chain: base,
  transport: http(),
});

const walletClient = createWalletClient({
  chain: base,
  transport: http(),
  account: '0x...',
});

// Initialize SDK
const escrow = new AgentEscrowClient(
  '0x...', // Escrow contract address
  publicClient,
  walletClient,
);

// Create an intent
const { hash, intentId } = await escrow.createIntent(
  {
    provider: '0x...',
    token: '0x...', // USDC address
    amount: 100_000000n, // 100 USDC (6 decimals)
    deadlineBlock: 1000000n,
    revealDeadline: BigInt(Date.now() / 1000 + 86400), // 24h from now
    fastMode: false,
    reputationMin: 500,
  },
  {
    description: 'AI model training task',
    deliverables: ['model.pth', 'training_metrics.json'],
  }
);

console.log('Intent created:', intentId);
```

## Core Clients

### AgentEscrowClient

Main contract for intent lifecycle management.

**Key Methods:**
- `createIntent()` - Create new intent with commit-reveal
- `revealIntent()` - Reveal service delivery
- `settle()` - Settle intent (permissionless)
- `finalizeNoReveal()` - Payer refund if no reveal
- `openDispute()` - Open dispute
- `withdrawCredit()` - Withdraw FastMode credits

### StakeManagerClient

Manage provider stakes.

**Key Methods:**
- `depositStake()` - Deposit stake
- `withdrawStake()` - Withdraw available stake
- `getTotalStake()` - Get total stake
- `getAvailableStake()` - Get available (unlocked) stake

### InsurancePoolClient

Handle insurance claims.

**Key Methods:**
- `deposit()` - Deposit to pool
- `claim()` - Execute insurance claim
- `getPoolBalance()` - Get pool balance

### ReputationClient

Query reputation scores.

**Key Methods:**
- `getScore()` - Get provider score (0-1000)
- `meetsThreshold()` - Check if meets threshold
- `getReputationPercentage()` - Get score as percentage

## Utilities

### Commit-Reveal
```typescript
import {
  generateServiceHash,
  generateSalt,
  encodeServicePreimage,
  decodeServicePreimage,
} from '@deagentic/sdk';

const salt = generateSalt();
const preimage = encodeServicePreimage({
  description: 'Service description',
  deliverables: ['file1.txt'],
});

const hash = generateServiceHash({
  chainId: 8453,
  escrowAddress: '0x...',
  intentId: '0x...',
  payer: '0x...',
  provider: '0x...',
  token: '0x...',
  amount: 100n,
  preimage,
});
```

### Intent ID Generation
```typescript
import { generateIntentId } from '@deagentic/sdk';

const intentId = generateIntentId({
  chainId: 8453,
  escrowAddress: '0x...',
  payer: '0x...',
  provider: '0x...',
  token: '0x...',
  amount: 100n,
  nonce: 1n,
});
```

## Network Addresses
```typescript
import { getAddresses, DEPLOYED_ADDRESSES } from '@deagentic/sdk';

// Get addresses for Base mainnet
const addresses = getAddresses(8453);

console.log(addresses.agentEscrow);
console.log(addresses.stakeManager);
console.log(addresses.insurancePool);
console.log(addresses.reputationRegistry);
```

## Examples

See the `examples/` directory for complete usage examples:

- `createIntent.ts` - Create and manage intents
- `revealAndSettle.ts` - Provider workflow
- `handleDispute.ts` - Dispute resolution

## Development
```bash
# Install dependencies
pnpm install

# Build
pnpm build

# Test
pnpm test

# Lint
pnpm lint
```

## License

MIT

## Links

- [Documentation](https://docs.deagentic.xyz)
- [GitHub](https://github.com/deagentic/protocol)
- [Website](https://deagentic.xyz)
