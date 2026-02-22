#!/bin/bash
set -e

echo "🔧 Correction test_RevealIntent_RevertInvalidHash..."

# Backup
cp test/AgentEscrow.t.sol test/AgentEscrow.t.sol.backup-invalidhash

# Trouver et remplacer le test
# Le test doit utiliser un mauvais salt au lieu d'un mauvais amount

# Trouver la ligne du test
LINE=$(grep -n "function test_RevealIntent_RevertInvalidHash" test/AgentEscrow.t.sol | cut -d: -f1)

if [ -z "$LINE" ]; then
    echo "❌ Test non trouvé"
    exit 1
fi

# Remplacer le test complet
# On va supprimer l'ancien et insérer le nouveau

# Trouver la fin du test (prochaine fonction ou })
END=$(awk "NR>$LINE && /^[[:space:]]*function |^[[:space:]]*}$/ {print NR; exit}" test/AgentEscrow.t.sol)

# Supprimer l'ancien test
sed -i "${LINE},$((END-1))d" test/AgentEscrow.t.sol

# Insérer le nouveau test
sed -i "${LINE}i\\
    function test_RevealIntent_RevertInvalidHash() public {\\
        bytes32 commitHash = _getCommitHash(provider, address(token), testAmount, testBond, testSalt);\\
        \\
        vm.prank(payer);\\
        bytes32 intentId = _createIntentDefault(commitHash);\\
        \\
        // Try to reveal with WRONG SALT (hash won't match)\\
        bytes32 wrongSalt = keccak256(\"wrong_salt\");\\
        vm.prank(payer);\\
        vm.expectRevert(IAgentEscrow.InvalidCommitHash.selector);\\
        escrow.revealIntent(intentId, provider, testBond, wrongSalt);\\
    }\\
" test/AgentEscrow.t.sol

echo "✅ Test corrigé"

