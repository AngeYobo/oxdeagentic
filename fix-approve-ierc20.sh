#!/bin/bash
set -e

echo "🔧 Remplacement MockERC20.approve par IERC20.approve..."

# Backup
cp test/AgentEscrow.t.sol test/AgentEscrow.t.sol.backup-ierc20

# Remplacer dans le helper
sed -i 's/MockERC20(_token)\.approve/IERC20(_token).approve/g' test/AgentEscrow.t.sol

echo "✅ MockERC20 remplacé par IERC20"

# Vérifier
echo ""
echo "Helper _createIntent maintenant:"
sed -n '/function _createIntent/,/^[[:space:]]*}/p' test/AgentEscrow.t.sol | head -12

