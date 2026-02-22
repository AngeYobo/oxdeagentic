#!/bin/bash
set -e

# D'abord supprimer le test bugué
sed -i '/function test_RevealIntent_RevertDifferentToken/,/^[[:space:]]*}$/d' test/AgentEscrow.t.sol

# Ajouter version corrigée avant la fermeture finale
# Trouver la dernière ligne }
LAST=$(wc -l < test/AgentEscrow.t.sol)

# Insérer le test corrigé avant la dernière ligne
sed -i "$((LAST))i\\
    /// @dev Bug #1: Should revert if reveal uses different token than create\\
    function test_Bug1_RevealDifferentToken() public {\\
        // Setup second token\\
        MockERC20 dai = new MockERC20(\"DAI\", \"DAI\", 18);\\
        \\
        vm.prank(arbiter);\\
        escrow.setMaxBondPerToken(address(dai), 1000 ether);\\
        escrow.setMaxPayerPayoutPerToken(address(dai), 100 ether);\\
        vm.stopPrank();\\
        \\
        bytes32 salt = keccak256(\"salt\");\\
        uint96 amount = 100 ether;\\
        uint96 bond = 10 ether;\\
        \\
        // Create with token (USDC)\\
        bytes32 commitHash = _getCommitHash(provider, address(token), amount, bond, salt);\\
        \\
        vm.prank(payer);\\
        bytes32 intentId = _createIntentDefault(commitHash);\\
        \\
        // Try reveal with DAI - should revert InvalidCommitHash\\
        vm.prank(payer);\\
        vm.expectRevert(IAgentEscrow.InvalidCommitHash.selector);\\
        escrow.revealIntent(intentId, provider, bond, salt);\\
    }\\
" test/AgentEscrow.t.sol

echo "✅ Test corrigé ajouté"

