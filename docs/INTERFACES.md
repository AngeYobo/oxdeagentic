# Interface Summary

## Contract Relationships
```
                    ┌─────────────┐
                    │ AgentEscrow │
                    │  (Orchestrator)
                    └──────┬──────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
    ┌──────▼──────┐ ┌─────▼──────┐ ┌─────▼──────────┐
    │StakeManager │ │InsurancePool│ │ReputationRegistry│
    └─────────────┘ └──────┬──────┘ └────────────────┘
                           │
                    (slash transfers)
```

## Interface Checklist

- ✅ `IReputationRegistry` - Reputation tracking with counterparty caps
- ✅ `IStakeManager` - Stake deposits, locks, bounded slashing
- ✅ `IInsurancePool` - Claims with bucket-based caps
- ✅ `IAgentEscrow` - Intent lifecycle orchestration

## Key Cross-Contract Calls

### AgentEscrow → StakeManager
- `lockStake()` - Lock 3x amount for fastMode
- `unlockStake()` - Release on terminal state
- `slash()` - Bounded slashing (≤50%)

### AgentEscrow → InsurancePool
- `authorizeClaim()` - Authorize payer claim during dispute
- `notifyDepositFromStake()` - Account bond slashes

### AgentEscrow → ReputationRegistry
- `recordSuccess()` - Record successful settlement

### StakeManager → InsurancePool
- `notifyDepositFromStake()` - Account stake slashes

### InsurancePool → AgentEscrow (view)
- `firstSeen()` - Get payer age for ramp calculation

## Deployment Order

1. Deploy ReputationRegistry (needs escrow address - can be placeholder)
2. Deploy InsurancePool (needs escrow address)
3. Deploy StakeManager (needs escrow + insurancePool)
4. Deploy AgentEscrow (needs all three addresses)
5. If ReputationRegistry used placeholder, redeploy or use proxy pattern

**Alternative:** Deploy AgentEscrow first with CREATE2, calculate address, then deploy others.

## Testing Dependencies

Each contract's test suite should include:
- Mock interfaces for dependencies
- Integration tests with real contracts
- Invariant tests for cross-contract invariants