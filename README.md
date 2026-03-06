# OxDeAgentic

**On-chain agentic task market with custodial escrow and pre-execution economic containment.**

OxDeAgentic is a Solidity protocol for autonomous agent task execution. Payers commit funds into custody at intent creation, providers fulfill work, and every settlement is verifiable on-chain. Economic boundaries are enforced by the [OxDeAI protocol](https://github.com/AngeYobo/oxdeai-core) before any tool or contract call executes.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Agent                                                      │
│    ↓  proposes task + intent                                │
│  OxDeAI PDP  ── evaluatePure(intent, state)                 │
│    ├─ DENY   → task rejected, no contract call              │
│    └─ ALLOW  → Authorization issued                         │
│         ↓                                                   │
│  AgentEscrow (orchestrator)                                 │
│    ↓  payer funds locked at createIntent                    │
│    ↓  provider revealed via commit-reveal                   │
│    ↓  settlement transfers from custody                     │
│    ↓  dispute → arbiter resolves + optional slash           │
└─────────────────────────────────────────────────────────────┘
         │                  │                    │
         ▼                  ▼                    ▼
  StakeManager       InsurancePool       ReputationRegistry
  lock/slash         claim auth          score tracking
```

**Phase 0 - Custodial Model:** Payer funds are transferred into escrow custody at `createIntent`. Settlement pushes directly from escrow to provider - no allowance dependency, no griefing surface.

---

## Contracts

| Contract | Description |
|---|---|
| `AgentEscrow` | Main orchestrator. Intent lifecycle, commit-reveal, FastMode credits, dispute initiation |
| `StakeManager` | Provider stake deposits, locking, and bounded slashing (≤50% cap) |
| `InsurancePool` | Bucket-based insurance claims with epoch/day caps and age ramp |
| `ReputationRegistry` | Per-epoch provider reputation with counterparty caps |

### Intent Lifecycle

```
NONE → COMMITTED → REVEALED → SETTLED
                             → DISPUTED → RESOLVED
                             → EXPIRED
```

### Timing Constants

| Constant | Value | Description |
|---|---|---|
| `REVEAL_DEADLINE` | 1 hour | Reveal window after commit |
| `SETTLEMENT_DEADLINE` | 24 hours | Settle window after reveal |
| `DISPUTE_DEADLINE` | 7 days | Dispute window after reveal |
| `FINALITY_GATE` | 3 days | Provider wait period |
| `CREDIT_EXPIRY` | 30 days | FastMode credit lifetime |

---

## Repository Structure

```
src/
  AgentEscrow.sol          - intent lifecycle, custody, disputes, FastMode
  StakeManager.sol         - stake lock/unlock/slash
  InsurancePool.sol        - insurance claims with bucket caps
  ReputationRegistry.sol   - epoch-based reputation
  interfaces/              - IAgentEscrow, IStakeManager, IInsurancePool, IReputationRegistry
  libraries/Types.sol      - shared types
test/
  AgentEscrow.t.sol        - 59 tests
  StakeManager.t.sol       - 37 tests
  InsurancePool.t.sol      - 39 tests
  ReputationRegistry.t.sol - 17 tests
  invariants/              - 11 invariant tests (15,360+ fuzzing calls)
  mocks/                   - MockStakeManager, MockReputationRegistry
script/                    - deployment scripts
deagentic-sdk/             - TypeScript SDK (submodule → @oxdeai/sdk)
docs/                      - protocol documentation
```

---

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) `>=0.2`
- Node.js `>=18`
- pnpm `>=9`

---

## Getting Started

```bash
git clone --recurse-submodules https://github.com/AngeYobo/oxdeagentic
cd OxDeAgentic

# Install Foundry dependencies
forge install

# Install SDK dependencies
cd deagentic-sdk && pnpm install && cd ..
```

### Build

```bash
forge build
```

### Test

```bash
forge test
```

```
Ran 165 tests across 8 suites - 165 passed, 0 failed ✔
```

### Coverage

```bash
forge coverage
```

---

## Test Results

| Suite | Tests | Status |
|---|---|---|
| AgentEscrow | 59 | ok |
| InsurancePool | 39 | ok |
| StakeManager | 37 | ok |
| ReputationRegistry | 17 | ok |
| InsurancePool Invariants | 4 (15,360 calls) | ok |
| StakeManager Invariants | 4 (15,360 calls) | ok |
| Reputation Invariants | 3 (15,360 calls) | ok |
| Counter | 2 | ok |
| **Total** | **165** | ok |

---

## Phase 0 - Custodial Model

The custodial model eliminates the allowance-based attack surface present in naive escrow designs:

1. **Payer** calls `createIntent(token, amount, commitHash)` - funds transferred to escrow custody atomically
2. **Payer** calls `revealIntent(intentId, provider, bond, salt)` - commit-reveal prevents front-running; provider stake locked
3. **Provider** calls `settleIntent(intentId, successGain)` - escrow pushes funds directly to provider; reputation recorded
4. **Dispute** - payer calls `initiateDispute`; arbiter calls `resolveDispute` with optional slash and insurance authorization
5. **Expiry** - anyone calls `expireIntent` after deadline; funds returned to payer

**FastMode:** Payers with reputation ≥ 800 can use pre-granted credits to skip stake locking, enabling lower-latency execution for trusted counterparties.

---

## Security

### Static Analysis (Slither)

| Severity | Count | Notes |
|---|---|---|
| High | 0 | - |
| Medium | 3 | `divide-before-multiply` in epoch/day bucket math - intentional floor rounding |
| Low | 2 | `reentrancy-events` - events after external calls; state committed before call |
| Informational | 21 | Naming conventions (UPPER_CASE constants), dead code, pragma versions |

### Security Properties

- **Custody at creation** - no allowance manipulation or griefing possible after `createIntent`
- **Commit-reveal** - provider parameters cryptographically bound at commit time
- **Bounded slashing** - `MAX_SLASH_BPS` enforced in `StakeManager`; provider can never lose more than bond
- **State machine monotonicity** - no rollbacks; each terminal state is final
- **ReentrancyGuard** - all state-changing functions protected
- **SafeERC20** - all token transfers use OpenZeppelin SafeERC20

### Known Considerations

- `block.timestamp` used for deadlines - standard for this use case; ±15s miner manipulation is within acceptable tolerance for 1-hour to 7-day windows
- Payers should grant **limited allowances** to the escrow (exactly `amount`) rather than unlimited
- `Counter.sol` uses `^0.8.13` pragma - legacy artifact, not part of the protocol

---

## OxDeAI Integration

Economic boundaries are enforced by `@oxdeai/core` before any on-chain call:

```typescript
import { OxDeAIClient } from "@oxdeai/sdk";

const client = new OxDeAIClient({ policyId, agentId });
const { decision, authorization } = await client.evaluate(intent, state);

if (decision === "ALLOW" && authorization) {
  // tool executes - contract call proceeds
  await escrow.createIntent(token, amount, commitHash);
} 
// DENY → no contract call, no gas spent, audit event emitted
```

See [`deagentic-sdk/examples/createIntent.ts`](./deagentic-sdk/examples/createIntent.ts) for a full example.

---

## npm Packages

| Package | Version | Description |
|---|---|---|
| [`@oxdeai/core`](https://www.npmjs.com/package/@oxdeai/core) | `1.0.3` | Policy engine, canonical snapshots, audit chaining |
| [`@oxdeai/sdk`](https://www.npmjs.com/package/@oxdeai/sdk) | `1.0.3` | TypeScript client wrapper |
| [`@oxdeai/conformance`](https://www.npmjs.com/package/@oxdeai/conformance) | `1.0.3` | Frozen conformance vectors (40/40 assertions) |

---

## Deployment

```bash
# Local devnet
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Testnet (Base Sepolia)
forge script script/Deploy.s.sol \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify
```

### Deployment Order

```
1. ReputationRegistry(escrowAddress)
2. InsurancePool(escrowAddress, stakeManagerAddress)
3. StakeManager(escrowAddress, insurancePoolAddress)
4. AgentEscrow(stakeManager, insurancePool, reputationRegistry, arbiter)
5. Configure permissions on each contract
```

---

## CI

GitHub Actions runs on every push:

- `forge build` - compilation
- `forge test` - 165 unit, integration, and invariant tests
- `@oxdeai/conformance validate` - 40/40 protocol conformance assertions

---

## Roadmap

- [x] Phase 0 - Custodial escrow model (complete)
- [x] 165 tests, 0 failures
- [x] Slither 0 high findings
- [ ] Professional security audit
- [ ] Testnet deployment (Base Sepolia)
- [ ] Bug bounty program
- [ ] Phase 1 - Non-custodial model with on-chain OxDeAI verification

---

## License

Apache-2.0 - see [LICENSE](./LICENSE)

---

## Related

- [oxdeai-core](https://github.com/AngeYobo/oxdeai-core) - OxDeAI protocol reference implementation and npm packages