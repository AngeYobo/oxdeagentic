#!/bin/bash
set -e

echo "🔧 Patching AgentEscrow for Escrow-Custody Model..."

# Backup
cp src/AgentEscrow.sol src/AgentEscrow.sol.backup-$(date +%s)

# 1. Dans revealIntent: Ajouter le pull de fonds APRÈS les validations
#    Trouver la ligne où on lock le stake et ajouter le transfer juste avant

# Créer le patch pour revealIntent
cat > /tmp/reveal-patch.txt << 'PATCH'
        // Pull funds from payer to escrow (escrow-custody model)
        IERC20(token).safeTransferFrom(intent.payer, address(this), amount);
        
PATCH

# Trouver la ligne exacte et insérer
LINE_NUM=$(grep -n "if (!usedCredit) {" src/AgentEscrow.sol | head -1 | grep "lockStake" | cut -d: -f1)
if [ -z "$LINE_NUM" ]; then
    LINE_NUM=$(grep -n "IStakeManager(stakeManager).lockStake" src/AgentEscrow.sol | head -1 | cut -d: -f1)
    LINE_NUM=$((LINE_NUM - 4))
fi

sed -i "${LINE_NUM}r /tmp/reveal-patch.txt" src/AgentEscrow.sol

# 2. Dans settleIntent: Remplacer safeTransferFrom par safeTransfer
sed -i 's/IERC20(intent\.token)\.safeTransferFrom(\s*intent\.payer,\s*intent\.provider,\s*intent\.amount\s*)/IERC20(intent.token).safeTransfer(intent.provider, intent.amount)/g' src/AgentEscrow.sol

# Alternative plus safe avec pattern matching
sed -i '/safeTransferFrom(intent\.payer, intent\.provider, intent\.amount)/c\        IERC20(intent.token).safeTransfer(intent.provider, intent.amount);' src/AgentEscrow.sol

# 3. Dans expireIntent: Ajouter refund au payer
# Trouver la ligne avec unlockStake et ajouter le transfer juste avant
LINE_NUM=$(grep -n "IStakeManager(stakeManager).unlockStake" src/AgentEscrow.sol | grep -A 5 "expireIntent" | head -1 | cut -d: -f1)
LINE_NUM=$((LINE_NUM - 1))

cat > /tmp/expire-patch.txt << 'PATCH'
        // Refund to payer (escrow-custody model)
        IERC20(intent.token).safeTransfer(intent.payer, intent.amount);
        
PATCH

sed -i "${LINE_NUM}r /tmp/expire-patch.txt" src/AgentEscrow.sol

echo "✅ Patch applied!"
echo "⚠️  VERIFY MANUALLY before compiling!"

