#!/bin/bash
set -e

echo "🔧 Création version custodiale complète..."
echo ""
echo "Cette migration nécessite:"
echo "1. Modifications AgentEscrow.sol (3 fonctions + 1 helper)"
echo "2. Modifications IAgentEscrow.sol (struct + signatures)"
echo "3. Réécriture TOUS les tests"
echo ""
echo "Temps estimé: 2-3 heures"
echo ""
read -p "Continuer? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Créer plan de migration détaillé
cat > MIGRATION_PLAN.md << 'PLAN'
# Plan de Migration Custodial Phase 0

## Phase 1: Interfaces & Structs (30 min)
- [ ] Modifier IAgentEscrow.Intent (ajouter nonce)
- [ ] Modifier IAgentEscrow.createIntent signature
- [ ] Modifier IAgentEscrow.revealIntent signature
- [ ] Compiler pour voir erreurs

## Phase 2: AgentEscrow.sol Core (60 min)
- [ ] Ajouter INTENT_COMMIT_DOMAIN constant
- [ ] Ajouter mapping intentNonce
- [ ] Créer _computeCommitHash helper
- [ ] Réécrire createIntent (custody transfer)
- [ ] Réécrire revealIntent (sans token/amount params)
- [ ] Modifier settleIntent (safeTransfer au lieu de safeTransferFrom)
- [ ] Compiler

## Phase 3: Tests Setup (30 min)
- [ ] Identifier tous les tests qui appellent createIntent
- [ ] Identifier tous les tests qui appellent revealIntent
- [ ] Créer helper function pour nouveau flow

## Phase 4: Tests Réécriture (60+ min)
- [ ] Adapter test_CreateIntent
- [ ] Adapter test_RevealIntent
- [ ] Adapter test_FullLifecycle_Success
- [ ] Adapter test_FullLifecycle_WithCredit
- [ ] Adapter TOUS les autres tests
- [ ] Forge test

## Phase 5: Validation (30 min)
- [ ] 44/44 tests AgentEscrow passants
- [ ] Coverage check
- [ ] Slither rerun
- [ ] Documentation

Total: ~3-4 heures
PLAN

cat MIGRATION_PLAN.md

echo ""
echo "📄 Plan créé: MIGRATION_PLAN.md"
echo ""
echo "Prochaine étape:"
echo "  Veux-tu que je:"
echo "    A) Modifie les fichiers un par un (guidé)"
echo "    B) Crée les fichiers modifiés complets d'un coup"
echo "    C) Commence par juste createIntent en mode minimal"
echo ""

