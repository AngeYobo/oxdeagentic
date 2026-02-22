#!/bin/bash
set -e

echo "🔧 Fix #2: settleIntent allowance check..."

# Backup
cp src/AgentEscrow.sol src/AgentEscrow.sol.before-settle-fix

# Supprimer les lignes allowance check
sed -i '/if (IERC20(intent.token).allowance(intent.payer, address(this)) < intent.amount)/,+2d' src/AgentEscrow.sol

# Supprimer commentaire slither obsolète
sed -i '/slither arbitrary-send-erc20.*payer must approve/d' src/AgentEscrow.sol

echo "✅ Allowance check supprimé"

