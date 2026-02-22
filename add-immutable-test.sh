#!/bin/bash
set -e

echo "📝 Ajout test TokenAmountImmutable..."

# Backup
cp test/AgentEscrow.t.sol test/AgentEscrow.t.sol.backup-immutable

# Trouver la ligne avant la fermeture finale du contrat
# On va insérer avant le dernier }
TOTAL=$(wc -l < test/AgentEscrow.t.sol)

# Insérer le test avant la dernière ligne
sed -i "${TOTAL}i\\
    // ══════════════════════════════════════════════════════════════════════════════\\
    // Security: Immutability Tests\\
    // ══════════════════════════════════════════════════════════════════════════════\\
    \\
    /// @dev Verify token and amount are immutable after creation (custodial model)\\
    function test_Security_TokenAmountImmutable() public {\\
        uint96 testAmount = 100 ether;\\
        uint96 testBond = 10 ether;\\
        bytes32 testSalt = keccak256(\"salt\");\\
        \\
        bytes32 commitHash = keccak256(abi.encodePacked(\\
            provider, address(token), testAmount, testBond, testSalt\\
        ));\\
        \\
        vm.startPrank(payer);\\
        deal(address(token), payer, testAmount);\\
        token.approve(address(escrow), type(uint256).max);\\
        bytes32 intentId = escrow.createIntent(address(token), testAmount, commitHash);\\
        \\
        // Capture initial values\\
        IAgentEscrow.Intent memory intentBefore = escrow.getIntent(intentId);\\
        address tokenBefore = intentBefore.token;\\
        uint96 amountBefore = intentBefore.amount;\\
        \\
        // Reveal should NOT modify token or amount\\
        escrow.revealIntent(intentId, provider, testBond, testSalt);\\
        \\
        // Verify token and amount remain unchanged\\
        IAgentEscrow.Intent memory intentAfter = escrow.getIntent(intentId);\\
        assertEq(intentAfter.token, tokenBefore, \"Token should be immutable\");\\
        assertEq(intentAfter.amount, amountBefore, \"Amount should be immutable\");\\
        \\
        // Additional verification: values match creation parameters\\
        assertEq(intentAfter.token, address(token), \"Token should match creation\");\\
        assertEq(intentAfter.amount, testAmount, \"Amount should match creation\");\\
        \\
        vm.stopPrank();\\
    }\\
" test/AgentEscrow.t.sol

echo "✅ Test ajouté"

