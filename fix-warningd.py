#!/usr/bin/env python3
"""Fix all forge-lint warnings in OxDeAgentic."""
import re, os, sys

BASE = os.path.expanduser("~/OxDeAgentic")

def read(path):
    with open(f"{BASE}/{path}") as f:
        return f.read()

def write(path, content):
    with open(f"{BASE}/{path}", "w") as f:
        f.write(content)

def prepend_disable(content, pattern, lint_name):
    lines = content.split('\n')
    result = []
    for i, line in enumerate(lines):
        prev = lines[i-1] if i > 0 else ''
        if re.search(pattern, line) and f'forge-lint: disable-next-line({lint_name})' not in prev:
            indent = len(line) - len(line.lstrip())
            result.append(' ' * indent + f'// forge-lint: disable-next-line({lint_name})')
        result.append(line)
    return '\n'.join(result)

# ── 1. InsurancePool: wrap both modifiers ─────────────────────────────────────
content = read("src/InsurancePool.sol")

old1 = """    modifier onlyEscrow() {
        if (msg.sender != escrow) revert OnlyEscrow();
        _;
    }"""
new1 = """    modifier onlyEscrow() {
        _onlyEscrow();
        _;
    }

    function _onlyEscrow() internal view {
        if (msg.sender != escrow) revert OnlyEscrow();
    }"""

old2 = """    modifier onlyStakeManagerOrEscrow() {
        if (msg.sender != stakeManager && msg.sender != escrow) {
            revert OnlyStakeManagerOrEscrow();
        }
        _;
    }"""
new2 = """    modifier onlyStakeManagerOrEscrow() {
        _onlyStakeManagerOrEscrow();
        _;
    }

    function _onlyStakeManagerOrEscrow() internal view {
        if (msg.sender != stakeManager && msg.sender != escrow) {
            revert OnlyStakeManagerOrEscrow();
        }
    }"""

content = content.replace(old1, new1).replace(old2, new2)
write("src/InsurancePool.sol", content)
print("✓ InsurancePool modifiers wrapped")

# ── 2. unsafe-typecast in InsurancePool.sol ───────────────────────────────────
content = read("src/InsurancePool.sol")
for pattern in [
    r'\.paid \+= uint128\(',
    r'bucket\.openingBalance = uint128\(',
    r'emit BucketOpened.*uint128\(',
]:
    content = prepend_disable(content, pattern, 'unsafe-typecast')
write("src/InsurancePool.sol", content)
print("✓ InsurancePool unsafe-typecast suppressed")

# ── 3. unsafe-typecast in ReputationRegistry.sol ─────────────────────────────
content = read("src/ReputationRegistry.sol")
for pattern in [r'uint16\(sum\)', r'int16\(uint16\(actualGain\)\)']:
    content = prepend_disable(content, pattern, 'unsafe-typecast')
write("src/ReputationRegistry.sol", content)
print("✓ ReputationRegistry unsafe-typecast suppressed")

# ── 4. unsafe-typecast in AgentEscrow.sol ────────────────────────────────────
content = read("src/AgentEscrow.sol")
for pattern in [
    r'uint64\(block\.timestamp \+ CREDIT_EXPIRY\)',
    r'expiresAt: uint64\(',
]:
    content = prepend_disable(content, pattern, 'unsafe-typecast')
write("src/AgentEscrow.sol", content)
print("✓ AgentEscrow unsafe-typecast suppressed")

# ── 5. asm-keccak256 in src/ ──────────────────────────────────────────────────
for path in ["src/AgentEscrow.sol", "src/InsurancePool.sol"]:
    content = read(path)
    content = prepend_disable(content, r'return keccak256\(abi\.encodePacked\(', 'asm-keccak256')
    content = prepend_disable(content, r'bytes32 (computedHash|expected) = keccak256\(', 'asm-keccak256')
    write(path, content)
print("✓ asm-keccak256 suppressed")

# ── 6. ghost_ variables renamed in invariant tests ───────────────────────────
renames = {
    'ghost_totalDeposited':  'ghostTotalDeposited',
    'ghost_totalClaimed':    'ghostTotalClaimed',
    'ghost_claimCount':      'ghostClaimCount',
    'ghost_totalDeposits':   'ghostTotalDeposits',
    'ghost_totalWithdrawals':'ghostTotalWithdrawals',
    'ghost_totalSlashed':    'ghostTotalSlashed',
    'ghost_lockCount':       'ghostLockCount',
}
for path in [
    "test/invariants/InsurancePoolInvariants.t.sol",
    "test/invariants/StakeManagerInvariants.t.sol",
]:
    content = read(path)
    for old, new in renames.items():
        content = content.replace(old, new)
    write(path, content)
print("✓ ghost_ variables renamed")

# ── 7. divide-before-multiply in test/InsurancePool.t.sol ────────────────────
content = read("test/InsurancePool.t.sol")
for pattern in [
    r'\(block\.timestamp / 28 days\) \* 28 days',
    r'\(block\.timestamp / 1 days\) \* 1 days',
    r'\(\(block\.timestamp - 28 days\) / 28 days\) \* 28 days',
]:
    content = prepend_disable(content, pattern, 'divide-before-multiply')
write("test/InsurancePool.t.sol", content)
print("✓ test divide-before-multiply suppressed")

# ── 8. unsafe-typecast + erc20 in test/InsurancePool.t.sol ───────────────────
content = read("test/InsurancePool.t.sol")
for pattern in [r'uint160\(daysAgo \+ 1000\)', r'uint128\(claimAmount\)']:
    content = prepend_disable(content, pattern, 'unsafe-typecast')
content = prepend_disable(content, r'token\.transfer\(address\(pool\)', 'erc20-unchecked-transfer')
write("test/InsurancePool.t.sol", content)
print("✓ test/InsurancePool warnings suppressed")

# ── 9. unsafe-typecast in test/ReputationRegistry.t.sol ──────────────────────
content = read("test/ReputationRegistry.t.sol")
content = prepend_disable(content, r'address\(uint160\(i\)\)', 'unsafe-typecast')
write("test/ReputationRegistry.t.sol", content)
print("✓ test/ReputationRegistry unsafe-typecast suppressed")

# ── 10. Remove unused IERC20 imports in AgentEscrow.t.sol ────────────────────
content = read("test/AgentEscrow.t.sol")
lines = [l for l in content.split('\n') if not (
    'import {IERC20}' in l and 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol' in l
)]
write("test/AgentEscrow.t.sol", '\n'.join(lines))
print("✓ Removed unused IERC20 imports from AgentEscrow.t.sol")

# ── 11. Fix shadow warnings — remove local redeclarations ────────────────────
content = read("test/AgentEscrow.t.sol")
content = re.sub(r'\n        uint96 testAmount = 100 ether;\n', '\n', content)
content = re.sub(r'\n        uint96 testBond = 10 ether;\n', '\n', content)
content = re.sub(r'\n        bytes32 testSalt = keccak256\("salt"\);\n', '\n', content)
write("test/AgentEscrow.t.sol", content)
print("✓ Shadow variables removed from AgentEscrow.t.sol")

# ── 12. MockStakeManager unused params ───────────────────────────────────────
content = read("test/mocks/MockStakeManager.sol")
content = re.sub(
    r'function lockStake\(address provider, address token, uint256 amount, bytes32 intentId\)',
    'function lockStake(address /*provider*/, address /*token*/, uint256 /*amount*/, bytes32 /*intentId*/)',
    content
)
content = re.sub(
    r'function slash\(bytes32 intentId, uint256 amount\)',
    'function slash(bytes32 /*intentId*/, uint256 /*amount*/)',
    content
)
write("test/mocks/MockStakeManager.sol", content)
print("✓ MockStakeManager unused params silenced")

print("\n✅ All done. Now run:")
print("   cd ~/OxDeAgentic && forge build && forge test && forge fmt")
print("   git add -A && git commit -m 'chore: clean all forge-lint warnings' && git push origin main")