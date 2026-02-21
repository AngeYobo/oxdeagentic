#!/bin/bash
set -e

echo "🔧 Application du modèle Escrow-Custody (v2)..."

# Backup
BACKUP="src/AgentEscrow.sol.backup-$(date +%Y%m%d-%H%M%S)"
cp src/AgentEscrow.sol "$BACKUP"
echo "✅ Backup créé: $BACKUP"

# ===== DIAGNOSTIC =====
echo "🔍 Diagnostic des patterns..."

echo "Patterns safeTransferFrom:"
grep -n "safeTransferFrom" src/AgentEscrow.sol || echo "Aucun safeTransferFrom trouvé"

echo ""
echo "Patterns dans settleIntent:"
sed -n '/function settleIntent/,/^[[:space:]]*}/p' src/AgentEscrow.sol | grep -n "transfer\|Transfer"

# ===== SECTION 1: revealIntent =====
echo ""
echo "📝 Section 1: Ajout pull funds dans revealIntent..."

# Insérer à la ligne 273, AVANT le lockStake
cat > /tmp/reveal_custody.patch << 'EOF'

        // Pull funds from payer to escrow (escrow-custody model)
        IERC20(token).safeTransferFrom(intent.payer, address(this), amount);
EOF

sed -i "273r /tmp/reveal_custody.patch" src/AgentEscrow.sol
echo "✅ Section 1 OK"

# ===== SECTION 2: settleIntent =====
echo "📝 Section 2: Modification dans settleIntent..."

# Trouver la ligne dans settleIntent
SETTLE_START=$(grep -n "function settleIntent" src/AgentEscrow.sol | cut -d: -f1)
echo "settleIntent commence à ligne: $SETTLE_START"

# Chercher transferFrom dans les 50 lignes suivantes
TRANSFER_LINE=$(sed -n "${SETTLE_START},$((SETTLE_START + 50))p" src/AgentEscrow.sol | grep -n "transferFrom" | head -1 | cut -d: -f1)

if [ -z "$TRANSFER_LINE" ]; then
    echo "⚠️  Pas de transferFrom trouvé dans settleIntent"
    echo "   Recherche de pattern alternatif..."
    
    # Afficher settleIntent pour inspection manuelle
    sed -n "${SETTLE_START},$((SETTLE_START + 50))p" src/AgentEscrow.sol
    
    echo ""
    echo "❌ Section 2 nécessite modification manuelle"
    echo "📁 Backup disponible: $BACKUP"
    exit 1
fi

# Calculer la ligne absolue
ABSOLUTE_LINE=$((SETTLE_START + TRANSFER_LINE - 1))
echo "transferFrom trouvé à ligne absolue: $ABSOLUTE_LINE"

# Afficher la ligne pour vérification
echo "Ligne actuelle:"
sed -n "${ABSOLUTE_LINE}p" src/AgentEscrow.sol

# Remplacer
sed -i "${ABSOLUTE_LINE}s/transferFrom.*/transfer(intent.provider, intent.amount);/" src/AgentEscrow.sol
echo "✅ Section 2 OK"

# ===== SECTION 3: expireIntent =====
echo "📝 Section 3: Ajout refund dans expireIntent..."

cat > /tmp/expire_custody.patch << 'EOF'

        // Refund to payer (escrow-custody model)
        IERC20(intent.token).safeTransfer(intent.payer, intent.amount);
EOF

sed -i "354r /tmp/expire_custody.patch" src/AgentEscrow.sol
echo "✅ Section 3 OK"

echo ""
echo "✅ Toutes les modifications appliquées!"
echo "📁 Backup: $BACKUP"

