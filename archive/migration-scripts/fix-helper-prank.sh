#!/bin/bash
set -e

echo "🔧 Correction des helpers (enlever pranks)..."

# Backup
cp test/AgentEscrow.t.sol test/AgentEscrow.t.sol.backup-prank

# Supprimer les lignes vm.startPrank et vm.stopPrank dans _createIntent
sed -i '/vm\.startPrank(_payer);/d' test/AgentEscrow.t.sol
sed -i '/vm\.stopPrank();/d' test/AgentEscrow.t.sol

echo "✅ Pranks enlevés des helpers"

# Vérifier
echo ""
echo "Helper _createIntent maintenant:"
sed -n '/function _createIntent/,/^[[:space:]]*}/p' test/AgentEscrow.t.sol | head -15

