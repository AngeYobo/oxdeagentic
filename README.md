# OxDeAgentic

**On-chain agentic task market with pre-execution economic containment.**

OxDeAgentic is a Solidity protocol for autonomous agent task execution. Agents propose work, budgets are enforced before execution, and every settlement is verifiable on-chain. Economic boundaries are enforced by the [OxDeAI protocol](https://github.com/AngeYobo/oxdeai-core) before any tool or contract call runs.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Agent                                                  │
│    ↓  proposes task + intent                            │
│  OxDeAI PDP  ─── evaluatePure(intent, state)            │
│    ├─ DENY   → task rejected, no contract call          │
│    └─ ALLOW  → Authorization issued                     │
│         ↓                                               │
│  TaskMarket (Solidity)                                  │
│    ↓  escrow locked                                     │
│    ↓  task executed                                     │
│    ↓  settlement verified                               │
│  Custodial Model  ─── funds released to provider        │
└─────────────────────────────────────────────────────────┘
```

**Custodial Model (Phase 0):** Client funds are held in escrow. The protocol enforces budget limits, velocity controls, and replay protection before any settlement executes.

---

## Repository Structure

```
src/                    — Solidity contracts
  TaskMarket.sol        — core task lifecycle (post, accept, complete, dispute)
  Escrow.sol            — custodial fund management
  interfaces/           — contract interfaces
test/                   — Foundry test suite (150 tests)
script/                 — deployment and migration scripts
migration-custodial/    — Phase 0 custodial migration artifacts
ai-task-market/         — task market modules
deagentic-sdk/          — TypeScript SDK (submodule → @oxdeai/sdk)
docs/                   — protocol documentation
lib/                    — Foundry dependencies
```

---

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) `^0.2`
- Node.js `>=18`
- pnpm `>=9`

---

## Getting Started

```bash
git clone --recurse-submodules https://github.com/AngeYobo/oxdeagentic
cd oxdeagentic

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
Ran 150 tests — all passing ✔
```

### Coverage

```bash
forge coverage
```

---

## Phase 0 — Custodial Model

The current deployment uses a custodial escrow model:

1. **Client** posts a task with a budget and locks funds in escrow
2. **Agent** accepts the task — OxDeAI evaluates the intent against policy before the contract call
3. **Execution** — tool runs only after Authorization is confirmed
4. **Settlement** — provider receives payment on verified completion
5. **Dispute** — unresolved tasks trigger escrow refund after timeout

Every settlement produces a hash-chained audit trail verifiable offline via `@oxdeai/conformance`.

---

## OxDeAI Integration

Economic boundaries are enforced by `@oxdeai/core` before any on-chain call:

```typescript
import { OxDeAIClient } from "@oxdeai/sdk";

const client = new OxDeAIClient({ policyId, agentId });
const { decision, authorization } = await client.evaluate(intent, state);

if (decision === "ALLOW" && authorization) {
  await taskMarket.acceptTask(taskId, authorization.id);
}
// DENY → no contract call, no gas spent
```

See [`deagentic-sdk/examples/createIntent.ts`](./deagentic-sdk/examples/createIntent.ts) for a full example.

---

## npm Packages

| Package | Version | Description |
|---|---|---|
| [`@oxdeai/core`](https://www.npmjs.com/package/@oxdeai/core) | `1.0.3` | Policy engine, canonical snapshots, audit chaining |
| [`@oxdeai/sdk`](https://www.npmjs.com/package/@oxdeai/sdk) | `1.0.3` | TypeScript client wrapper |
| [`@oxdeai/conformance`](https://www.npmjs.com/package/@oxdeai/conformance) | `1.0.3` | Frozen test vectors + conformance runner |

---

## Deployment

```bash
# Local devnet
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Testnet
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
```

---

## CI

GitHub Actions runs on every push:

- `forge build` — contract compilation
- `forge test` — 150 unit and integration tests
- `@oxdeai/conformance validate` — 40/40 protocol conformance assertions

---

## License

Apache-2.0 — see [LICENSE](./LICENSE)

---

## Related

- [oxdeai-core](https://github.com/AngeYobo/oxdeai-core) — OxDeAI protocol reference implementation
- [OxDeAI Protocol Specification v1.0](https://github.com/AngeYobo/oxdeai-core/tree/main/packages/core)