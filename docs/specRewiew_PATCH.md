# CANONICAL PATCH BLOCK — Phase 0 Spec v1.0 (exact replacement text)

## 1) Replace in **B.1 AgentEscrow → External Interfaces → createIntent(...) → Effects**
**REPLACE the entire “Effects” bullet list under `createIntent(...)` with:**

**Effects (atomic, canonical ordering)**

* initialize `firstSeen[payer]` if unset
* token support check (coherence):  
  `MAX_BOND_PER_TOKEN[token] > 0 && MAX_PAYER_PAYOUT_PER_TOKEN[token] > 0`
* reputation gate (with bounded ERC-8004 boost; cannot bypass hard invariants)
* compute `intentId` with domain separation: `CHAIN_ID` + `address(this)` + economic tuple + `nonce`
* **if fastMode:** lock stake **before custody**:  
  `stakeManager.lockStake(provider, token, LOCK_MULTIPLIER * amount, intentId)`  
  *(if lock fails → revert; no partial state; no custody transfer)*
* pull `amount` in `token` from payer into escrow custody:  
  `SafeERC20.safeTransferFrom(IERC20(token), payer, address(this), amount)`
* write intent state = `CREATED` (and persist all intent fields, including `serviceHash`, `deadlineBlock`, `revealDeadline`, `flags`, `reputationMin`)
* emit `IntentCreated(intentId, payer, provider, token, amount, flags, deadlineBlock, revealDeadline, serviceHash)`


---

## 2) Replace in **C.3.1 Credit Creation** (fastMode condition)
**REPLACE:**
* `intent.fastMode == true`

**WITH:**
* `(intent.flags & FAST_MODE) != 0`


---

## 3) Replace in **C.3.4 Withdrawal** (remove duplicate execution-order block)
**REPLACE the entire duplicated section starting at:**
“### Execution order (reentrancy-safe, CEI)”
(the second duplicate block)

**WITH:**
*(Delete this duplicate block entirely; no replacement text.)*

**Result:** C.3.4 MUST contain exactly one “Execution order (reentrancy-safe)” block (the first one).


---

## 4) Replace in **G. Development Order (dependency graph)** — AgentEscrow core line
**REPLACE this line:**
* `settle + finalizeNoReveal with finality gate`

**WITH:**
* `settle with finality gate (INV-6); finalizeNoReveal without finality gate (time-only liveness)`


---

## 5) InsurancePool balance model (choose Option A: canonical accounting + permissionless sync)
### 5.1 Replace in **B.3 InsurancePool → Critical State Variables → Pool balances**
**REPLACE:**
* `mapping(address token => uint256) public poolBalance;`

**WITH:**
* `mapping(address token => uint256) public accountedBalance;`  
  *(canonical accounting balance used for snapshots/caps; may drift from ERC20 `balanceOf` if tokens are sent directly without calling notify — addressed via `sync()` below)*


### 5.2 Replace in **B.3 InsurancePool → External Interfaces → Funding → deposit(token, amount)**
**REPLACE the two “Effects” bullets with:**

* increases `accountedBalance[token]` by `amount` **after** successful `safeTransferFrom`
* emits `PoolDeposited(token, from, amount)`


### 5.3 Replace in **B.3 InsurancePool → External Interfaces → Accounting notification (push deposit path) → notifyDepositFromStake(token, amount)**
**REPLACE the “Effects” bullet with:**

* increase `accountedBalance[token]` by `amount`
* emit `PoolDeposited(token, msg.sender, amount)`


### 5.4 Replace in **B.3 InsurancePool → Internal Logic Modules → _ensureOpeningBalanceSnapshot(...)**
**REPLACE:**
* “if `openingBalance == 0` set to current `poolBalance[token]` …”

**WITH:**
* if `openingBalance == 0`, set `openingBalance = uint128(accountedBalance[token])`  
  *(requires `accountedBalance[token] > 0`; if zero, revert with a specific error e.g. `EmptyBucket()`)*


### 5.5 Insert in **B.3 InsurancePool → External Interfaces** (add a canonical permissionless `sync`)
**INSERT this new subsection (verbatim) anywhere under “External Interfaces” (recommended after `deposit` and `notifyDepositFromStake`):**

#### Accounting reconciliation (permissionless)

`sync(token)`

Reconciles `accountedBalance[token]` to the actual ERC-20 balance to prevent “stuck liquidity” when tokens are transferred directly to the pool without calling `deposit()` or `notifyDepositFromStake()`.

**Preconditions:**
- `token != address(0)`

**Effects:**
- `accountedBalance[token] = IERC20(token).balanceOf(address(this))`
- emit `PoolSynced(token, accountedBalance[token])`

**Notes (audit posture):**
- `sync()` is permissionless and does not transfer funds.
- Bucket snapshots and cap enforcement MUST use `accountedBalance[token]` (not raw `balanceOf`) for determinism.
- Operators may call `sync()` before the first claim in a bucket to ensure the openingBalance snapshot reflects all liquidity.


### 5.6 Replace in **D. Invariant Enforcement Mapping → INV-3 Protection**
**REPLACE the last clause:**
“reconcile against IERC20 balance”

**WITH:**
“permissionless `sync(token)` reconciles `accountedBalance[token]` against `IERC20(token).balanceOf(address(this))` prior to snapshotting and/or claim execution, preventing accounting drift.”


### 5.7 Add required event (InsurancePool)
**INSERT into B.3 Required Events (audit / telemetry):**
* `PoolSynced(token, newAccountedBalance)`


# END CANONICAL PATCH BLOCK
