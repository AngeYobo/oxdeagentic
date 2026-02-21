#!/bin/bash

echo "🔍 Diagnostic de la structure du code..."
echo ""

# 1. Trouver revealIntent
echo "=== 1. Fonction revealIntent ==="
LINE_START=$(grep -n "function revealIntent" src/AgentEscrow.sol | cut -d: -f1)
echo "revealIntent commence à la ligne: $LINE_START"

# 2. Chercher lockStake dans tout le fichier
echo ""
echo "=== 2. Toutes les occurrences de lockStake ==="
grep -n "lockStake" src/AgentEscrow.sol

# 3. Afficher revealIntent complet
echo ""
echo "=== 3. Code de revealIntent (premières 60 lignes) ==="
sed -n "${LINE_START},$((LINE_START + 60))p" src/AgentEscrow.sol

# 4. Chercher le pattern exact dans revealIntent
echo ""
echo "=== 4. Pattern IStakeManager dans revealIntent ==="
awk -v start="$LINE_START" 'NR >= start && /function revealIntent/,/^[[:space:]]*}/ {print NR": "$0}' src/AgentEscrow.sol | grep -i "stake" | head -10

