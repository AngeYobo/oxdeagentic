#!/bin/bash
set -e

echo "🔧 Application du modèle Escrow-Custody (FINAL)..."

# Backup
BACKUP="src/AgentEscrow.sol.backup-escrow-custody-final"
cp src/AgentEscrow.sol "$BACKUP"
echo "✅ Backup créé: $BACKUP"

# ===== SECTION 1: revealIntent - Pull funds =====
echo "📝 Section 1: Pull funds dans revealIntent (avant ligne 275)..."

# Insérer à la ligne 273 (juste avant le lockStake)
sed -i '273i\
\        // Pull funds from payer to escrow (escrow-custody model)\
\        IERC20(token).safeTransferFrom(intent.payer, address(this), amount);
' src/AgentEscrow.sol

echo "✅ Section 1 appliquée"

# ===== SECTION 2: settleIntent - Change transferFrom to transfer =====
echo "📝 Section 2: Remplacement multi-lignes dans settleIntent..."

# Le safeTransferFrom est sur les lignes 324-328
# On va remplacer ces 5 lignes par une seule ligne avec safeTransfer

# D'abord, supprimer les lignes 325-328 (garder 324 pour la remplacer)
sed -i '325,328d' src/AgentEscrow.sol

# Maintenant remplacer la ligne 324 (qui était la première du bloc)
sed -i '324s/.*/        IERC20(intent.token).safeTransfer(intent.provider, intent.amount);/' src/AgentEscrow.sol

echo "✅ Section 2 appliquée"

# ===== SECTION 3: expireIntent - Refund =====
echo "📝 Section 3: Refund dans expireIntent..."

# expireIntent commence après settleIntent
# On doit recalculer car on a supprimé 4 lignes
# Ligne originale 356 - 4 = 352

# Chercher dynamiquement la ligne unlockStake dans expireIntent
EXPIRE_LINE=$(awk '/function expireIntent/,/^[[:space:]]*}/ {
    if (/IStakeManager.*unlockStake/) {print NR; exit}
}' src/AgentEscrow.sol)

if [ -z "$EXPIRE_LINE" ]; then
    echo "❌ Erreur: unlockStake dans expireIntent non trouvé"
    cp "$BACKUP" src/AgentEscrow.sol
    exit 1
fi

echo "unlockStake dans expireIntent trouvé à ligne: $EXPIRE_LINE"

# Insérer 2 lignes avant
INSERT_LINE=$((EXPIRE_LINE - 1))

sed -i "${INSERT_LINE}i\
\        // Refund to payer (escrow-custody model)\
\        IERC20(intent.token).safeTransfer(intent.payer, intent.amount);
" src/AgentEscrow.sol

echo "✅ Section 3 appliquée (ligne $INSERT_LINE)"

# ===== VÉRIFICATION =====
echo ""
echo "🔍 Vérification des modifications..."
echo ""

echo "=== Section 1: Pull funds dans revealIntent ==="
sed -n '273,278p' src/AgentEscrow.sol
echo ""

echo "=== Section 2: safeTransfer dans settleIntent ==="
sed -n '322,327p' src/AgentEscrow.sol
echo ""

echo "=== Section 3: Refund dans expireIntent ==="
REFUND_LINE=$(grep -n "Refund to payer" src/AgentEscrow.sol | cut -d: -f1)
sed -n "$((REFUND_LINE)),$((REFUND_LINE + 5))p" src/AgentEscrow.sol
echo ""

echo "✅ Toutes les modifications appliquées!"
echo ""
echo "📁 Backup: $BACKUP"
echo ""
echo "🧪 Prochaines étapes:"
echo "   forge build"
echo "   forge test --match-contract AgentEscrowTest"

