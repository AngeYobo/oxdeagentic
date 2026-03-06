**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [arbitrary-send-erc20](#arbitrary-send-erc20) (1 results) (High)
 - [divide-before-multiply](#divide-before-multiply) (3 results) (Medium)
 - [reentrancy-events](#reentrancy-events) (2 results) (Low)
 - [timestamp](#timestamp) (10 results) (Low)
 - [assembly](#assembly) (1 results) (Informational)
 - [pragma](#pragma) (1 results) (Informational)
 - [cyclomatic-complexity](#cyclomatic-complexity) (1 results) (Informational)
 - [dead-code](#dead-code) (1 results) (Informational)
 - [solc-version](#solc-version) (2 results) (Informational)
 - [low-level-calls](#low-level-calls) (5 results) (Informational)
 - [naming-convention](#naming-convention) (21 results) (Informational)
## arbitrary-send-erc20
Impact: High
Confidence: High
 - [ ] ID-0
[AgentEscrow.settleIntent(bytes32,uint16)](src/AgentEscrow.sol#L290-L329) uses arbitrary from in transferFrom: [IERC20(intent.token).safeTransferFrom(intent.payer,intent.provider,intent.amount)](src/AgentEscrow.sol#L322-L326)

src/AgentEscrow.sol#L290-L329


## divide-before-multiply
Impact: Medium
Confidence: Medium
 - [ ] ID-1
[InsurancePool._bucketDayStart(uint256)](src/InsurancePool.sol#L454-L456) performs a multiplication on the result of a division:
	- [(timestamp / DAY_SECONDS) * DAY_SECONDS](src/InsurancePool.sol#L455)

src/InsurancePool.sol#L454-L456


 - [ ] ID-2
[InsurancePool._bucketEpochStart(uint256)](src/InsurancePool.sol#L445-L447) performs a multiplication on the result of a division:
	- [(timestamp / EPOCH_SECONDS) * EPOCH_SECONDS](src/InsurancePool.sol#L446)

src/InsurancePool.sol#L445-L447


 - [ ] ID-3
[ReputationRegistry.getCurrentEpoch()](src/ReputationRegistry.sol#L148-L150) performs a multiplication on the result of a division:
	- [(block.timestamp / EPOCH_SECONDS) * EPOCH_SECONDS](src/ReputationRegistry.sol#L149)

src/ReputationRegistry.sol#L148-L150


## reentrancy-events
Impact: Low
Confidence: Medium
 - [ ] ID-4
Reentrancy in [StakeManager.slash(bytes32,uint256)](src/StakeManager.sol#L214-L241):
	External calls:
	- [IERC20(token).safeTransfer(insurancePool,amount)](src/StakeManager.sol#L235)
	- [IInsurancePool(insurancePool).notifyDepositFromStake(token,amount)](src/StakeManager.sol#L238)
	Event emitted after the call(s):
	- [StakeSlashed(intentId,provider,token,amount)](src/StakeManager.sol#L240)

src/StakeManager.sol#L214-L241


 - [ ] ID-5
Reentrancy in [AgentEscrow.expireIntent(bytes32)](src/AgentEscrow.sol#L334-L352):
	External calls:
	- [IStakeManager(stakeManager).unlockStake(intentId)](src/AgentEscrow.sol#L348)
	Event emitted after the call(s):
	- [IntentExpired(intentId,uint64(block.timestamp))](src/AgentEscrow.sol#L351)

src/AgentEscrow.sol#L334-L352


## timestamp
Impact: Low
Confidence: Medium
 - [ ] ID-6
[AgentEscrow.canUseCredit(address,address,uint256)](src/AgentEscrow.sol#L550-L561) uses timestamp for comparisons
	Dangerous comparisons:
	- [credit.status == IAgentEscrow.CreditStatus.ACTIVE && credit.remainingAmount >= amount && block.timestamp <= credit.expiresAt](src/AgentEscrow.sol#L558-L560)

src/AgentEscrow.sol#L550-L561


 - [ ] ID-7
[AgentEscrow.expireIntent(bytes32)](src/AgentEscrow.sol#L334-L352) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp <= intent.revealedAt + DISPUTE_DEADLINE](src/AgentEscrow.sol#L339)

src/AgentEscrow.sol#L334-L352


 - [ ] ID-8
[InsurancePool._enforceCaps(IInsurancePool.Claim,uint256,uint256,uint256)](src/InsurancePool.sol#L323-L372) uses timestamp for comparisons
	Dangerous comparisons:
	- [requestedAmount > ageAdjustedCap](src/InsurancePool.sol#L370)

src/InsurancePool.sol#L323-L372


 - [ ] ID-9
[InsurancePool._getAgeAdjustedCap(address,address)](src/InsurancePool.sol#L380-L400) uses timestamp for comparisons
	Dangerous comparisons:
	- [firstSeenTimestamp > block.timestamp](src/InsurancePool.sol#L390)
	- [age >= RAMP_SECONDS](src/InsurancePool.sol#L396)

src/InsurancePool.sol#L380-L400


 - [ ] ID-10
[InsurancePool.expireClaim(bytes32)](src/InsurancePool.sol#L156-L165) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp <= claimData.authorizedAt + CLAIM_TTL](src/InsurancePool.sol#L160)

src/InsurancePool.sol#L156-L165


 - [ ] ID-11
[AgentEscrow.revealIntent(bytes32,address,address,uint96,uint96,bytes32)](src/AgentEscrow.sol#L211-L285) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp > intent.committedAt + REVEAL_DEADLINE](src/AgentEscrow.sol#L224)
	- [credit.status == IAgentEscrow.CreditStatus.ACTIVE && credit.remainingAmount >= amount && block.timestamp <= credit.expiresAt](src/AgentEscrow.sol#L259-L261)

src/AgentEscrow.sol#L211-L285


 - [ ] ID-12
[InsurancePool._executeClaim(bytes32)](src/InsurancePool.sol#L267-L317) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp > claimData.authorizedAt + CLAIM_TTL](src/InsurancePool.sol#L273)

src/InsurancePool.sol#L267-L317


 - [ ] ID-13
[AgentEscrow.settleIntent(bytes32,uint16)](src/AgentEscrow.sol#L290-L329) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp > intent.revealedAt + SETTLEMENT_DEADLINE](src/AgentEscrow.sol#L300)

src/AgentEscrow.sol#L290-L329


 - [ ] ID-14
[AgentEscrow.expireCredit(bytes32)](src/AgentEscrow.sol#L499-L508) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp <= credit.expiresAt](src/AgentEscrow.sol#L503)

src/AgentEscrow.sol#L499-L508


 - [ ] ID-15
[AgentEscrow.initiateDispute(bytes32,string)](src/AgentEscrow.sol#L361-L390) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp > intent.revealedAt + DISPUTE_DEADLINE](src/AgentEscrow.sol#L373)

src/AgentEscrow.sol#L361-L390


## assembly
Impact: Informational
Confidence: High
 - [ ] ID-16
[Address._revert(bytes)](lib/openzeppelin-contracts/contracts/utils/Address.sol#L146-L158) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/Address.sol#L151-L154)

lib/openzeppelin-contracts/contracts/utils/Address.sol#L146-L158


## pragma
Impact: Informational
Confidence: High
 - [ ] ID-17
3 different versions of Solidity are used:
	- Version constraint ^0.8.20 is used by:
		-[^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/utils/Address.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol#L4)
	- Version constraint ^0.8.23 is used by:
		-[^0.8.23](src/AgentEscrow.sol#L2)
		-[^0.8.23](src/InsurancePool.sol#L2)
		-[^0.8.23](src/ReputationRegistry.sol#L2)
		-[^0.8.23](src/StakeManager.sol#L2)
		-[^0.8.23](src/interfaces/IAgentEscrow.sol#L2)
		-[^0.8.23](src/interfaces/IInsurancePool.sol#L2)
		-[^0.8.23](src/interfaces/IReputationRegistry.sol#L2)
		-[^0.8.23](src/interfaces/IStakeManager.sol#L2)
		-[^0.8.23](src/libraries/Types.sol#L2)
	- Version constraint ^0.8.13 is used by:
		-[^0.8.13](src/Counter.sol#L2)

lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol#L4


## cyclomatic-complexity
Impact: Informational
Confidence: High
 - [ ] ID-18
[AgentEscrow.revealIntent(bytes32,address,address,uint96,uint96,bytes32)](src/AgentEscrow.sol#L211-L285) has a high cyclomatic complexity (12).

src/AgentEscrow.sol#L211-L285


## dead-code
Impact: Informational
Confidence: Medium
 - [ ] ID-19
[AgentEscrow._generateIntentId(address,bytes32)](src/AgentEscrow.sol#L598-L609) is never used and should be removed

src/AgentEscrow.sol#L598-L609


## solc-version
Impact: Informational
Confidence: High
 - [ ] ID-20
Version constraint ^0.8.20 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- VerbatimInvalidDeduplication
	- FullInlinerNonExpressionSplitArgumentEvaluationOrder
	- MissingSideEffectsOnSelectorAccess.
It is used by:
	- [^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/utils/Address.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol#L4)

lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol#L4


 - [ ] ID-21
Version constraint ^0.8.13 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- VerbatimInvalidDeduplication
	- FullInlinerNonExpressionSplitArgumentEvaluationOrder
	- MissingSideEffectsOnSelectorAccess
	- StorageWriteRemovalBeforeConditionalTermination
	- AbiReencodingHeadOverflowWithStaticArrayCleanup
	- DirtyBytesArrayToStorage
	- InlineAssemblyMemorySideEffects
	- DataLocationChangeInInternalOverride
	- NestedCalldataArrayAbiReencodingSizeValidation.
It is used by:
	- [^0.8.13](src/Counter.sol#L2)

src/Counter.sol#L2


## low-level-calls
Impact: Informational
Confidence: High
 - [ ] ID-22
Low level call in [Address.functionStaticCall(address,bytes)](lib/openzeppelin-contracts/contracts/utils/Address.sol#L95-L98):
	- [(success,returndata) = target.staticcall(data)](lib/openzeppelin-contracts/contracts/utils/Address.sol#L96)

lib/openzeppelin-contracts/contracts/utils/Address.sol#L95-L98


 - [ ] ID-23
Low level call in [Address.functionDelegateCall(address,bytes)](lib/openzeppelin-contracts/contracts/utils/Address.sol#L104-L107):
	- [(success,returndata) = target.delegatecall(data)](lib/openzeppelin-contracts/contracts/utils/Address.sol#L105)

lib/openzeppelin-contracts/contracts/utils/Address.sol#L104-L107


 - [ ] ID-24
Low level call in [SafeERC20._callOptionalReturnBool(IERC20,bytes)](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L110-L117):
	- [(success,returndata) = address(token).call(data)](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L115)

lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L110-L117


 - [ ] ID-25
Low level call in [Address.sendValue(address,uint256)](lib/openzeppelin-contracts/contracts/utils/Address.sol#L41-L50):
	- [(success,None) = recipient.call{value: amount}()](lib/openzeppelin-contracts/contracts/utils/Address.sol#L46)

lib/openzeppelin-contracts/contracts/utils/Address.sol#L41-L50


 - [ ] ID-26
Low level call in [Address.functionCallWithValue(address,bytes,uint256)](lib/openzeppelin-contracts/contracts/utils/Address.sol#L83-L89):
	- [(success,returndata) = target.call{value: value}(data)](lib/openzeppelin-contracts/contracts/utils/Address.sol#L87)

lib/openzeppelin-contracts/contracts/utils/Address.sol#L83-L89


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-27
Function [IAgentEscrow.CREDIT_EXPIRY()](src/interfaces/IAgentEscrow.sol#L166) is not in mixedCase

src/interfaces/IAgentEscrow.sol#L166


 - [ ] ID-28
Function [IAgentEscrow.FINALITY_GATE()](src/interfaces/IAgentEscrow.sol#L165) is not in mixedCase

src/interfaces/IAgentEscrow.sol#L165


 - [ ] ID-29
Variable [InsurancePool.CHAIN_ID](src/InsurancePool.sol#L49) is not in mixedCase

src/InsurancePool.sol#L49


 - [ ] ID-30
Function [IInsurancePool.EPOCH_SECONDS()](src/interfaces/IInsurancePool.sol#L205) is not in mixedCase

src/interfaces/IInsurancePool.sol#L205


 - [ ] ID-31
Function [IInsurancePool.CLAIM_TTL()](src/interfaces/IInsurancePool.sol#L208) is not in mixedCase

src/interfaces/IInsurancePool.sol#L208


 - [ ] ID-32
Function [IAgentEscrow.SETTLEMENT_DEADLINE()](src/interfaces/IAgentEscrow.sol#L163) is not in mixedCase

src/interfaces/IAgentEscrow.sol#L163


 - [ ] ID-33
Function [IStakeManager.MAX_SLASH_BPS()](src/interfaces/IStakeManager.sol#L157) is not in mixedCase

src/interfaces/IStakeManager.sol#L157


 - [ ] ID-34
Variable [InsurancePool.MAX_PAYER_PAYOUT_PER_TOKEN](src/InsurancePool.sol#L76) is not in mixedCase

src/InsurancePool.sol#L76


 - [ ] ID-35
Function [IAgentEscrow.MAX_BOND_PER_TOKEN(address)](src/interfaces/IAgentEscrow.sol#L159) is not in mixedCase

src/interfaces/IAgentEscrow.sol#L159


 - [ ] ID-36
Variable [AgentEscrow.MAX_PAYER_PAYOUT_PER_TOKEN](src/AgentEscrow.sol#L105) is not in mixedCase

src/AgentEscrow.sol#L105


 - [ ] ID-37
Function [IInsurancePool.RAMP_SECONDS()](src/interfaces/IInsurancePool.sol#L207) is not in mixedCase

src/interfaces/IInsurancePool.sol#L207


 - [ ] ID-38
Variable [AgentEscrow.CHAIN_ID](src/AgentEscrow.sol#L67) is not in mixedCase

src/AgentEscrow.sol#L67


 - [ ] ID-39
Function [IERC20Permit.DOMAIN_SEPARATOR()](lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol#L89) is not in mixedCase

lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol#L89


 - [ ] ID-40
Function [IAgentEscrow.DISPUTE_DEADLINE()](src/interfaces/IAgentEscrow.sol#L164) is not in mixedCase

src/interfaces/IAgentEscrow.sol#L164


 - [ ] ID-41
Function [IInsurancePool.MAX_PAYER_PAYOUT_PER_TOKEN(address)](src/interfaces/IInsurancePool.sol#L200) is not in mixedCase

src/interfaces/IInsurancePool.sol#L200


 - [ ] ID-42
Function [IAgentEscrow.REVEAL_DEADLINE()](src/interfaces/IAgentEscrow.sol#L162) is not in mixedCase

src/interfaces/IAgentEscrow.sol#L162


 - [ ] ID-43
Function [IAgentEscrow.FASTMODE_THRESHOLD()](src/interfaces/IAgentEscrow.sol#L167) is not in mixedCase

src/interfaces/IAgentEscrow.sol#L167


 - [ ] ID-44
Function [IAgentEscrow.CHAIN_ID()](src/interfaces/IAgentEscrow.sol#L168) is not in mixedCase

src/interfaces/IAgentEscrow.sol#L168


 - [ ] ID-45
Variable [AgentEscrow.MAX_BOND_PER_TOKEN](src/AgentEscrow.sol#L102) is not in mixedCase

src/AgentEscrow.sol#L102


 - [ ] ID-46
Function [IInsurancePool.DAY_SECONDS()](src/interfaces/IInsurancePool.sol#L206) is not in mixedCase

src/interfaces/IInsurancePool.sol#L206


 - [ ] ID-47
Function [IAgentEscrow.MAX_PAYER_PAYOUT_PER_TOKEN(address)](src/interfaces/IAgentEscrow.sol#L160) is not in mixedCase

src/interfaces/IAgentEscrow.sol#L160


