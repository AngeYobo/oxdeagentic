#!/bin/bash

echo "🔍 Vérification des modifications Escrow-Custody"
echo ""

# Section 1
echo "=== 1. Pull funds dans revealIntent (ligne ~273-275) ==="
sed -n '271,280p' src/AgentEscrow.sol
echo ""

# Section 2  
echo "=== 2. safeTransfer dans settleIntent (ligne ~324) ==="
sed -n '320,330p' src/AgentEscrow.sol
echo ""

# Section 3
echo "=== 3. Refund dans expireIntent ==="
grep -B2 -A5 "Refund to payer" src/AgentEscrow.sol
echo ""

# Compter les occurrences
echo "=== Compteurs ==="
echo "Pull funds (devrait être 1): $(grep -c "Pull funds from payer to escrow" src/AgentEscrow.sol)"
echo "Refund to payer (devrait être 1): $(grep -c "Refund to payer" src/AgentEscrow.sol)"
echo "safeTransfer intent.provider (devrait être 1): $(grep -c "safeTransfer(intent.provider" src/AgentEscrow.sol)"
echo "safeTransferFrom intent.payer (devrait être 0): $(grep -c "safeTransferFrom.*intent.payer.*intent.provider" src/AgentEscrow.sol || echo "0")"

