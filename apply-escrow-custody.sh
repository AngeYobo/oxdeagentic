#!/bin/bash
set -e

echo "🔧 Application du modèle Escrow-Custody..."

# Backup
BACKUP="src/AgentEscrow.sol.backup-$(date +%Y%m%d-%H%M%S)"
cp src/AgentEscrow.sol "$BACKUP"
echo "✅ Backup créé: $BACKUP"

# ===== SECTION 1: revealIntent =====
echo "📝 Section 1: Ajout pull funds dans revealIntent..."

LINE_NUM=$(awk '/function revealIntent/,/^[[:space:]]*}/ {
    if (/IStakeManager.*lockStake/) print NR; exit
}' src/AgentEscrow.sol)

if [ -z "$LINE_NUM" ]; then
    echo "❌ Erreur: lockStake dans revealIntent non trouvé"
    exit 1
fi

INSERT_LINE=$((LINE_NUM - 2))

cat > /tmp/reveal_custody.patch << 'EOF'

        // Pull funds from payer to escrow (escrow-custody model)
        IERC20(token).safeTransferFrom(intent.payer, address(this), amount);
EOF

sed -i "${INSERT_LINE}r /tmp/reveal_custody.patch" src/AgentEscrow.sol
echo "✅ Section 1 OK (ligne $INSERT_LINE)"

# ===== SECTION 2: settleIntent =====
echo "📝 Section 2: Remplacement transferFrom par transfer dans settleIntent..."

# Vérifier que le pattern existe
if ! grep -q "safeTransferFrom.*intent.payer.*intent.provider.*intent.amount" src/AgentEscrow.sol; then
    echo "❌ Erreur: Pattern safeTransferFrom non trouvé"
    exit 1
fi

sed -i 's/IERC20(intent\.token)\.safeTransferFrom(intent\.payer, intent\.provider, intent\.amount)/IERC20(intent.token).safeTransfer(intent.provider, intent.amount)/g' src/AgentEscrow.sol
echo "✅ Section 2 OK"

# ===== SECTION 3: expireIntent =====
echo "📝 Section 3: Ajout refund dans expireIntent..."

LINE_NUM=$(awk '/function expireIntent/,/^[[:space:]]*}/ {
    if (/IStakeManager.*unlockStake/) print NR; exit
}' src/AgentEscrow.sol)

if [ -z "$LINE_NUM" ]; then
    echo "❌ Erreur: unlockStake dans expireIntent non trouvé"
    exit 1
fi

INSERT_LINE=$((LINE_NUM - 1))

cat > /tmp/expire_custody.patch << 'EOF'

        // Refund to payer (escrow-custody model)
        IERC20(intent.token).safeTransfer(intent.payer, intent.amount);
EOF

sed -i "${INSERT_LINE}r /tmp/expire_custody.patch" src/AgentEscrow.sol
echo "✅ Section 3 OK (ligne $INSERT_LINE)"

# ===== VÉRIFICATION =====
echo ""
echo "🔍 Vérification des modifications..."

echo "=== Section 1 (revealIntent) ==="
grep -A 5 "Pull funds from payer to escrow" src/AgentEscrow.sol | head -6

echo ""
echo "=== Section 2 (settleIntent) ==="
grep -B 2 -A 2 "safeTransfer.*intent.provider.*intent.amount" src/AgentEscrow.sol | head -10

echo ""
echo "=== Section 3 (expireIntent) ==="
grep -A 5 "Refund to payer" src/AgentEscrow.sol | head -6

echo ""
echo "✅ Modifications appliquées avec succès!"
echo "⚠️  Veuillez compiler et tester:"
echo "    forge build"
echo "    forge test --match-contract AgentEscrowTest"
echo ""
echo "📁 Backup disponible: $BACKUP"

