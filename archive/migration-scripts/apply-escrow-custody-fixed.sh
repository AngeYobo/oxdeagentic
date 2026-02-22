#!/bin/bash
set -e

echo "🔧 Application du modèle Escrow-Custody..."

# Backup
BACKUP="src/AgentEscrow.sol.backup-$(date +%Y%m%d-%H%M%S)"
cp src/AgentEscrow.sol "$BACKUP"
echo "✅ Backup créé: $BACKUP"

# ===== SECTION 1: revealIntent =====
echo "📝 Section 1: Ajout pull funds dans revealIntent..."

# Le lockStake est à la ligne 275
# On insère AVANT, donc à la ligne 273 (2 lignes avant pour avoir l'indentation)
INSERT_LINE=273

cat > /tmp/reveal_custody.patch << 'EOF'

        // Pull funds from payer to escrow (escrow-custody model)
        IERC20(token).safeTransferFrom(intent.payer, address(this), amount);
EOF

sed -i "${INSERT_LINE}r /tmp/reveal_custody.patch" src/AgentEscrow.sol
echo "✅ Section 1 OK (insertion ligne $INSERT_LINE)"

# ===== SECTION 2: settleIntent =====
echo "📝 Section 2: Remplacement transferFrom par transfer dans settleIntent..."

# Chercher la ligne exacte avec safeTransferFrom
LINE_NUM=$(grep -n "safeTransferFrom.*intent\.payer.*intent\.provider" src/AgentEscrow.sol | cut -d: -f1)

if [ -z "$LINE_NUM" ]; then
    echo "❌ Erreur: safeTransferFrom non trouvé"
    cp "$BACKUP" src/AgentEscrow.sol
    exit 1
fi

echo "safeTransferFrom trouvé à ligne: $LINE_NUM"

# Remplacer cette ligne
sed -i "${LINE_NUM}s/.*/        IERC20(intent.token).safeTransfer(intent.provider, intent.amount);/" src/AgentEscrow.sol
echo "✅ Section 2 OK (ligne $LINE_NUM modifiée)"

# ===== SECTION 3: expireIntent =====
echo "📝 Section 3: Ajout refund dans expireIntent..."

# Le dernier unlockStake (ligne 356) est celui dans expireIntent
# On insère AVANT
INSERT_LINE=354

cat > /tmp/expire_custody.patch << 'EOF'

        // Refund to payer (escrow-custody model)
        IERC20(intent.token).safeTransfer(intent.payer, intent.amount);
EOF

sed -i "${INSERT_LINE}r /tmp/expire_custody.patch" src/AgentEscrow.sol
echo "✅ Section 3 OK (insertion ligne $INSERT_LINE)"

# ===== VÉRIFICATION =====
echo ""
echo "🔍 Vérification des modifications..."
echo ""

echo "=== Section 1 (revealIntent - ligne ~275) ==="
sed -n '273,280p' src/AgentEscrow.sol

echo ""
echo "=== Section 2 (settleIntent - safeTransfer) ==="
grep -n "safeTransfer.*intent\.provider.*intent\.amount" src/AgentEscrow.sol | head -1
sed -n "$((LINE_NUM-1)),$((LINE_NUM+1))p" src/AgentEscrow.sol

echo ""
echo "=== Section 3 (expireIntent - ligne ~356) ==="
sed -n '354,361p' src/AgentEscrow.sol

echo ""
echo "✅ Modifications appliquées avec succès!"
echo ""
echo "📁 Backup: $BACKUP"
echo ""
echo "🧪 Prochaines étapes:"
echo "   forge build"
echo "   forge test --match-contract AgentEscrowTest"

