# Correctifs Custodial - Plan d'Action

## Bug #1: revealIntent (CRITIQUE)
**Impact:** Peut mélanger tokens entre intents
**Fix:** Supprimer params token/amount, utiliser intent.token/amount

## Bug #2: settleIntent
**Impact:** Peut revert à tort
**Fix:** Supprimer check allowance

## Bug #3: expireIntent
**Impact:** Double unlock, double emit
**Fix:** Supprimer doublons

## Bug #4: Tests ne détectent pas
**Impact:** Faux sentiment de sécurité
**Fix:** Ajouter tests avec token/amount différents

## Ordre de Correction

1. ✅ Fix revealIntent (le plus critique)
2. ✅ Fix settleIntent (allowance check)
3. ✅ Fix expireIntent (doublons)
4. ✅ Ajouter tests edge cases
5. ✅ Rerun 150 tests
6. ✅ Slither revalidation

