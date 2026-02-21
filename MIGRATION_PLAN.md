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
