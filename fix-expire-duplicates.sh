#!/bin/bash
set -e

echo "🔧 Fix #3: expireIntent doublons..."

# Backup
cp src/AgentEscrow.sol src/AgentEscrow.sol.before-expire-fix

echo "⚠️  Modification manuelle requise dans expireIntent()"
echo ""
echo "SUPPRIMER à la fin de la fonction:"
echo "  - emit IntentExpired (doublon)"
echo "  - unlockStake (doublon)"
echo ""
echo "GARDER un seul emit IntentExpired à la fin"

