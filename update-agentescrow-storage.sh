#!/bin/bash
set -e

echo "📝 Étape 1: Ajout storage variables..."

# Trouver ligne après les mappings existants
# Ajouter:
# 1. INTENT_COMMIT_DOMAIN constant
# 2. mapping intentNonce (pour tracking nonce par intent)

# Script sera complexe, faisons manuellement d'abord

echo "⚠️  Modification manuelle requise:"
echo "1. Ajouter après line ~67 (CHAIN_ID):"
echo ""
echo "    bytes32 internal constant INTENT_COMMIT_DOMAIN = keccak256(\"DEAI_INTENT_COMMIT_V1\");"
echo ""
echo "2. Ajouter après les mappings existants:"
echo ""
echo "    mapping(bytes32 => uint64) public intentNonce;"
echo ""

