#!/bin/bash
set -e

echo "🔧 Application Escrow-Custody (Simple)..."

# Backup
cp src/AgentEscrow.sol src/AgentEscrow.sol.backup-simple
echo "✅ Backup créé"

# Section 1: Pull funds
echo "📝 Section 1: Pull funds..."
LINE=$(grep -n "IStakeManager(stakeManager).lockStake" src/AgentEscrow.sol | head -1 | cut -d: -f1)
sed -i "$((LINE - 1))i\\
\\
        // Pull funds from payer to escrow (escrow-custody model)\\
        IERC20(token).safeTransferFrom(intent.payer, address(this), amount);" src/AgentEscrow.sol
echo "✅ Done"

# Section 2: Change transferFrom
echo "📝 Section 2: safeTransfer..."
LINE=$(grep -n "IERC20(intent.token).safeTransferFrom" src/AgentEscrow.sol | head -1 | cut -d: -f1)
sed -i "${LINE},$((LINE + 4))d" src/AgentEscrow.sol
sed -i "${LINE}i\\
        IERC20(intent.token).safeTransfer(intent.provider, intent.amount);" src/AgentEscrow.sol
echo "✅ Done"

# Section 3: Refund
echo "📝 Section 3: Refund..."
START=$(grep -n "function expireIntent" src/AgentEscrow.sol | cut -d: -f1)
LINE=$(awk -v s=$START 'NR > s && /IStakeManager.*unlockStake/ {print NR; exit}' src/AgentEscrow.sol)
sed -i "$((LINE - 1))i\\
\\
        // Refund to payer (escrow-custody model)\\
        IERC20(intent.token).safeTransfer(intent.payer, intent.amount);" src/AgentEscrow.sol
echo "✅ Done"

# Verify
echo ""
echo "✅ Modifications appliquées:"
echo "   Pull funds: $(grep -c "Pull funds" src/AgentEscrow.sol)"
echo "   Refund: $(grep -c "Refund to payer" src/AgentEscrow.sol)"
echo "   safeTransfer provider: $(grep -c "safeTransfer(intent.provider" src/AgentEscrow.sol)"

