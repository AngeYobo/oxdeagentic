#!/bin/bash
set -e

echo "🔧 Mise à jour signature createIntent dans l'interface..."

# Backup
cp src/interfaces/IAgentEscrow.sol src/interfaces/IAgentEscrow.sol.backup-newsig

# Supprimer ancienne ligne 119
sed -i '119d' src/interfaces/IAgentEscrow.sol

# Insérer nouvelle signature à la ligne 119
sed -i '119i\    function createIntent(\n        address token,\n        uint96 amount,\n        bytes32 commitHash\n    ) external returns (bytes32 intentId);' src/interfaces/IAgentEscrow.sol

echo "✅ Signature mise à jour"

# Vérifier
echo ""
echo "Nouvelle signature:"
sed -n '119,123p' src/interfaces/IAgentEscrow.sol

# Compiler
echo ""
forge build

