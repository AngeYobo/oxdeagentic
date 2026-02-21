#!/bin/bash
set -e

echo "🔧 Ajout error UnsupportedToken()..."

# Backup
cp src/interfaces/IAgentEscrow.sol src/interfaces/IAgentEscrow.sol.backup-error

# Trouver ligne avec d'autres errors (ex: après InvalidAddress)
LINE=$(grep -n "error InvalidAddress" src/interfaces/IAgentEscrow.sol | head -1 | cut -d: -f1)

if [ -z "$LINE" ]; then
    echo "❌ Impossible de trouver section errors"
    exit 1
fi

echo "Ajout après ligne $LINE"

# Ajouter après InvalidAddress
sed -i "${LINE}a\\    error UnsupportedToken();" src/interfaces/IAgentEscrow.sol

echo "✅ Error ajouté dans IAgentEscrow.sol"

# Compiler pour vérifier
forge build

