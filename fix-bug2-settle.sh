#!/bin/bash
set -e

echo "🔧 Bug #2: settleIntent allowance..."

# Backup
cp src/AgentEscrow.sol src/AgentEscrow.sol.backup-bug2

# Trouver et supprimer le bloc allowance check
# Chercher "Optional: explicit allowance" jusqu'à la ligne suivante avec }
sed -i '/Optional: explicit allowance check/,/^[[:space:]]*}$/{
    /Optional: explicit allowance/,/revert InsufficientAllowance/d
    /^[[:space:]]*}$/d
}' src/AgentEscrow.sol

# Alternative plus sûre: supprimer lignes précises
LINE_START=$(grep -n "Optional: explicit allowance" src/AgentEscrow.sol | cut -d: -f1)
if [ ! -z "$LINE_START" ]; then
    # Supprimer 4 lignes (commentaire + if + revert + })
    sed -i "${LINE_START},$((LINE_START+3))d" src/AgentEscrow.sol
fi

echo "✅ Bug #2 corrigé"

