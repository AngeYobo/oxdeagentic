#!/bin/bash
set -e

echo "🔧 Bug #3: expireIntent doublons..."

# Backup
cp src/AgentEscrow.sol src/AgentEscrow.sol.backup-bug3

# Trouver la fonction expireIntent et supprimer les 2 dernières lignes
# Stratégie: chercher le dernier emit IntentExpired et supprimer 2 lignes avant

# Trouver toutes les lignes avec emit IntentExpired dans expireIntent
FUNC_START=$(grep -n "function expireIntent" src/AgentEscrow.sol | cut -d: -f1)
FUNC_END=$(awk "NR>$FUNC_START && /^[[:space:]]*}$/ {print NR; exit}" src/AgentEscrow.sol)

# Trouver la dernière ligne emit IntentExpired dans cette fonction
LAST_EMIT=$(awk "NR>=$FUNC_START && NR<=$FUNC_END && /emit IntentExpired/ {line=NR} END {print line}" src/AgentEscrow.sol)

if [ ! -z "$LAST_EMIT" ]; then
    # Supprimer cette ligne et la précédente (unlockStake)
    sed -i "$((LAST_EMIT-1)),${LAST_EMIT}d" src/AgentEscrow.sol
fi

echo "✅ Bug #3 corrigé"

