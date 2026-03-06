#!/bin/bash
set -e

echo "🔍 Vérification de la structure du SDK..."
echo ""

FILES=(
  "package.json"
  "tsconfig.json"
  "src/index.ts"
  "src/core/AgentEscrow.ts"
  "src/core/StakeManager.ts"
  "src/core/InsurancePool.ts"
  "src/core/Reputation.ts"
  "src/utils/commitReveal.ts"
  "src/utils/intentId.ts"
  "src/types/intent.ts"
  "src/types/dispute.ts"
  "src/types/credit.ts"
  "src/constants/addresses.ts"
)

MISSING=0

for file in "${FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "✅ $file"
  else
    echo "❌ $file - MANQUANT"
    MISSING=$((MISSING + 1))
  fi
done

echo ""
if [ $MISSING -eq 0 ]; then
  echo "✅ Tous les fichiers requis sont présents"
else
  echo "❌ $MISSING fichiers manquants"
fi
