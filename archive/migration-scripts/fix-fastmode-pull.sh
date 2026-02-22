#!/bin/bash
set -e

echo "🔧 Fix: Pull funds pour FastMode..."

# Backup
cp src/AgentEscrow.sol src/AgentEscrow.sol.before-fastmode-fix

# Le problème: Pull funds est DANS le else block
# Solution: Déplacer AVANT le if/else

# 1. Trouver la ligne avec notre "Pull funds" comment
PULL_LINE=$(grep -n "Pull funds from payer to escrow" src/AgentEscrow.sol | cut -d: -f1)
echo "Pull funds actuellement à ligne: $PULL_LINE"

# 2. Supprimer les 3 lignes (comment + code + ligne vide)
sed -i "${PULL_LINE},$((PULL_LINE + 2))d" src/AgentEscrow.sol

# 3. Trouver le début du bloc if/else (la ligne avec "if (credit.status")
IF_LINE=$(awk '/function revealIntent/,/^[[:space:]]*}/ {
    if (/if \(credit\.status == IAgentEscrow\.CreditStatus\.ACTIVE/) {print NR; exit}
}' src/AgentEscrow.sol)

echo "Bloc if/else trouvé à ligne: $IF_LINE"

# 4. Insérer AVANT le if
INSERT_LINE=$((IF_LINE - 1))

sed -i "${INSERT_LINE}i\\
        // Pull funds from payer to escrow (escrow-custody model)\\
        IERC20(token).safeTransferFrom(intent.payer, address(this), amount);\\
" src/AgentEscrow.sol

echo "✅ Pull funds déplacé à ligne $INSERT_LINE (avant if/else)"
echo ""
echo "Vérification:"
sed -n "$((INSERT_LINE)),$((INSERT_LINE + 15))p" src/AgentEscrow.sol

