#!/bin/bash
set -e

echo "🔧 Correction automatique des 3 bugs custodial..."
echo ""

# Backup complet
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
cp src/AgentEscrow.sol "src/AgentEscrow.sol.backup-$TIMESTAMP"
cp src/interfaces/IAgentEscrow.sol "src/interfaces/IAgentEscrow.sol.backup-$TIMESTAMP"

echo "✅ Backups créés: AgentEscrow.sol.backup-$TIMESTAMP"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# BUG #1: revealIntent - Signature + Hash Calculation
# ══════════════════════════════════════════════════════════════════════════════

echo "🔧 Fix #1: revealIntent signature et hash..."

# 1A. Modifier la signature dans l'interface
# Remplacer la signature avec 6 params par celle avec 4 params
sed -i '/function revealIntent(/,/external;/{
    /function revealIntent(/c\    function revealIntent(\
        bytes32 intentId,\
        address provider,\
        uint96 bond,\
        bytes32 salt\
    ) external;
    /bytes32 intentId,/d
    /address provider,/d
    /address token,/d
    /uint96 amount,/d
    /uint96 bond,/d
    /bytes32 salt/d
}' src/interfaces/IAgentEscrow.sol

# 1B. Modifier la signature dans l'implémentation
# Supprimer les lignes token et amount de la signature
sed -i '/function revealIntent(/,/external nonReentrant {/{
    /address token,/d
    /uint96 amount,/d
}' src/AgentEscrow.sol

# 1C. Modifier le calcul du hash
# Remplacer "token," par "intent.token," dans le keccak256
sed -i '/bytes32 computedHash = keccak256(abi.encodePacked(/,/));/{
    s/provider,$/provider,/
    s/token,$/intent.token,/
    s/amount,$/intent.amount,/
}' src/AgentEscrow.sol

echo "  ✅ revealIntent signature: 6 params → 4 params"
echo "  ✅ Hash calculation: token/amount → intent.token/intent.amount"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# BUG #2: settleIntent - Supprimer allowance check
# ══════════════════════════════════════════════════════════════════════════════

echo "🔧 Fix #2: settleIntent allowance check..."

# Supprimer le commentaire + le bloc if allowance
sed -i '/Optional: explicit allowance check/,/revert InsufficientAllowance/d' src/AgentEscrow.sol

# Supprimer la ligne fermante du if
sed -i '/IERC20(intent.token).safeTransfer(intent.provider, intent.amount);/{
    N
    s/^\([[:space:]]*\)IERC20.*\n[[:space:]]*}/\1IERC20(intent.token).safeTransfer(intent.provider, intent.amount);/
}' src/AgentEscrow.sol

echo "  ✅ Allowance check supprimé"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# BUG #3: expireIntent - Supprimer doublons
# ══════════════════════════════════════════════════════════════════════════════

echo "🔧 Fix #3: expireIntent doublons..."

# Trouver et supprimer les 2 dernières lignes d'expireIntent
# (après le premier emit IntentExpired)
sed -i '/function expireIntent/,/^[[:space:]]*}$/{
    # Marquer la première occurrence de emit IntentExpired
    /emit IntentExpired(intentId, uint64(block.timestamp));/{
        # Si suivi de unlockStake puis emit à nouveau, supprimer ces 2 lignes
        N
        N
        s/\(emit IntentExpired.*\)\n[[:space:]]*IStakeManager.*unlockStake.*\n[[:space:]]*emit IntentExpired.*/\1/
    }
}' src/AgentEscrow.sol

echo "  ✅ Doublons supprimés (unlockStake + emit)"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# Vérification
# ══════════════════════════════════════════════════════════════════════════════

echo "🧪 Vérification des modifications..."
echo ""

# Check 1: revealIntent signature
echo "1. revealIntent signature dans interface:"
grep -A 5 "function revealIntent" src/interfaces/IAgentEscrow.sol | head -6

echo ""
echo "2. revealIntent signature dans implémentation:"
grep -A 6 "function revealIntent" src/AgentEscrow.sol | head -7

echo ""
echo "3. Hash calculation:"
grep -A 6 "bytes32 computedHash = keccak256" src/AgentEscrow.sol | head -7

echo ""
echo "4. settleIntent (pas d'allowance check):"
grep -B 2 -A 2 "safeTransfer(intent.provider, intent.amount)" src/AgentEscrow.sol

echo ""
echo "5. expireIntent (un seul emit):"
grep -A 5 "emit IntentExpired" src/AgentEscrow.sol | grep -v "^--$"

echo ""
echo "✅ Corrections appliquées!"
echo ""
echo "Prochaines étapes:"
echo "  1. forge build"
echo "  2. forge test"
echo "  3. Vérifier que 150 tests passent"

