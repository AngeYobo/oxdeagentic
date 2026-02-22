#!/bin/bash
set -e

echo "🔧 Fix #1: revealIntent custodial..."

# Backup
cp src/AgentEscrow.sol src/AgentEscrow.sol.before-reveal-fix

# La nouvelle signature dans l'interface est déjà correcte:
# function revealIntent(bytes32 intentId, address provider, uint96 bond, bytes32 salt)

# Mais l'implémentation doit être corrigée
# On va créer le bon code manuellement

echo "⚠️  Modification manuelle requise dans src/AgentEscrow.sol"
echo ""
echo "Dans revealIntent():"
echo "1. SUPPRIMER params: address token, uint96 amount"
echo "2. SUPPRIMER lignes: intent.token = token; intent.amount = amount;"
echo "3. Calculer hash avec intent.token et intent.amount (déjà stockés)"
echo ""
echo "Version correcte:"
cat << 'EOF'

function revealIntent(
    bytes32 intentId,
    address provider,
    uint96 bond,
    bytes32 salt
) external nonReentrant {
    Intent storage intent = intents[intentId];
    
    if (intent.state != IAgentEscrow.IntentState.COMMITTED) {
        revert InvalidIntentState();
    }
    if (msg.sender != intent.payer) {
        revert OnlyPayer();
    }
    
    // Calculate hash using STORED token/amount
    bytes32 computedHash = keccak256(
        abi.encodePacked(
            provider,
            intent.token,    // ✅ From storage
            intent.amount,   // ✅ From storage
            bond,
            salt
        )
    );
    
    if (computedHash != intent.commitHash) {
        revert InvalidCommitHash();
    }
    
    // Validate bond
    if (bond > intent.amount) {
        revert BondExceedsAmount();
    }
    if (bond > MAX_BOND_PER_TOKEN[intent.token]) {
        revert BondExceedsMax();
    }
    
    // Update intent (NO token/amount modification)
    intent.provider = provider;
    intent.bond = bond;
    intent.revealedAt = uint64(block.timestamp);
    intent.state = IAgentEscrow.IntentState.REVEALED;
    
    emit IntentRevealed(intentId, provider, uint64(block.timestamp));
}
EOF

