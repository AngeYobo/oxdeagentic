# Allowance Model Documentation

## Design Decision

AgentEscrow uses an **allowance-based model** where:
1. Payer creates intent with commit hash
2. Payer grants ERC20 allowance to AgentEscrow
3. Provider reveals intent parameters
4. On settlement, AgentEscrow pulls funds from payer to provider

## Security Analysis

### Slither Finding: arbitrary-send-erc20
**Status:** Accepted by design
**Justification:**
- `intent.payer` is immutably set at `createIntent()` by `msg.sender`
- `intent.provider` is verified via commit-reveal hash
- Commit hash prevents parameter substitution
- Payer must explicitly approve AgentEscrow
- Protected by ReentrancyGuard

### Risk Mitigation
1. **Commit-reveal prevents front-running**: Provider cannot change parameters
2. **Intent.payer is immutable**: Set once at creation
3. **Hash verification**: Provider must reveal correct parameters
4. **Time limits**: REVEAL_DEADLINE, SETTLEMENT_DEADLINE, DISPUTE_DEADLINE
5. **Comprehensive tests**: 150 tests, 98.79% coverage

### Known Considerations
- Payers should use **limited allowances** rather than unlimited
- If payer revokes allowance before settlement, tx will revert (not a security issue)
- Standard pattern used by: Uniswap, 1inch, 0x Protocol

## Alternative Considered

**Escrow-custody model** (pull at reveal, push at settle):
- **Pros**: Eliminates Slither finding, prevents allowance manipulation
- **Cons**: More complex, funds locked during disputes, breaks existing tests
- **Decision**: Allowance model preferred for simplicity and gas efficiency

## Recommendation for Audit

Document this design decision and request auditor review of:
1. Intent.payer immutability
2. Commit-reveal hash verification
3. Time-based security guarantees
