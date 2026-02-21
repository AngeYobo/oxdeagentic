#!/bin/bash
set -e

echo "🔧 Modification IAgentEscrow.sol..."

# Backup
cp src/interfaces/IAgentEscrow.sol src/interfaces/IAgentEscrow.sol.backup-custodial

# Créer nouvelle version
cat > src/interfaces/IAgentEscrow.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IAgentEscrow {
    // ... (garder tous les enums, structs, errors existants)
    // MAIS modifier struct Intent pour ajouter nonce
    
    struct Intent {
        address payer;
        address provider;
        address token;
        uint96 amount;
        uint96 bond;
        bytes32 commitHash;
        uint64 committedAt;
        uint64 revealedAt;
        uint64 settledAt;
        uint64 nonce;          // ✅ AJOUTÉ
        IntentState state;
        bool usedCredit;
    }
    
    // Nouvelles signatures Phase 0
    function createIntent(
        address token,
        uint96 amount,
        bytes32 commitHash
    ) external returns (bytes32 intentId);
    
    function revealIntent(
        bytes32 intentId,
        address provider,
        uint96 bond,
        bytes32 salt
    ) external;
    
    // ... (reste identique)
}
EOF

echo "✅ Interface modifiée"
