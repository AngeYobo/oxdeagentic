#!/bin/bash
set -e

echo "🔧 Remplacement mint() par deal()..."

# Backup
cp test/AgentEscrow.t.sol test/AgentEscrow.t.sol.backup-deal

# Remplacer MockERC20(_token).mint(_payer, _amount) par deal(_token, _payer, _amount)
sed -i 's/MockERC20(_token)\.mint(_payer, _amount);/deal(_token, _payer, _amount);/g' test/AgentEscrow.t.sol

echo "✅ mint() remplacé par deal()"

# Vérifier
echo ""
echo "Helper _createIntent maintenant:"
sed -n '/function _createIntent/,/^[[:space:]]*}/p' test/AgentEscrow.t.sol | head -12

