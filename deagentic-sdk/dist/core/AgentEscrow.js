"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AgentEscrowClient = void 0;
const viem_1 = require("viem");
const intentId_1 = require("../utils/intentId");
const commitReveal_1 = require("../utils/commitReveal");
const AgentEscrow_json_1 = __importDefault(require("../constants/abis/AgentEscrow.json"));
/**
 * AgentEscrow client for interacting with the escrow contract
 */
class AgentEscrowClient {
    constructor(address, publicClient, walletClient) {
        this.address = address;
        this.publicClient = publicClient;
        this.walletClient = walletClient;
        this.chainId = publicClient.chain.id;
    }
    getReadContract() {
        return (0, viem_1.getContract)({
            address: this.address,
            abi: AgentEscrow_json_1.default,
            client: this.publicClient,
        });
    }
    getWriteContract() {
        if (!this.walletClient) {
            throw new Error('Wallet client required for write operations');
        }
        return (0, viem_1.getContract)({
            address: this.address,
            abi: AgentEscrow_json_1.default,
            client: this.walletClient,
        });
    }
    // ═══════════════════════════════════════════════════════════════
    // READ METHODS
    // ═══════════════════════════════════════════════════════════════
    async getIntent(intentId) {
        const contract = this.getReadContract();
        const intent = await contract.read.getIntent([intentId]);
        return {
            payer: intent.payer,
            provider: intent.provider,
            token: intent.token,
            amount: intent.amount,
            deadlineBlock: intent.deadlineBlock,
            revealDeadline: intent.revealDeadline,
            revealTimestamp: intent.revealTimestamp,
            reputationMin: intent.reputationMin,
            flags: intent.flags,
            state: intent.state,
            serviceHash: intent.serviceHash,
            nonce: intent.nonce,
        };
    }
    async getDispute(intentId) {
        const contract = this.getReadContract();
        const dispute = await contract.read.getDispute([intentId]);
        return {
            status: dispute.status,
            openedAt: dispute.openedAt,
            evidenceHash: dispute.evidenceHash,
            bondAmount: dispute.bondAmount,
        };
    }
    async getCredit(intentId) {
        const contract = this.getReadContract();
        const credit = await contract.read.getCredit([intentId]);
        return {
            token: credit.token,
            provider: credit.provider,
            amount: credit.amount,
            createdAt: credit.createdAt,
            unlockAt: credit.unlockAt,
            status: credit.status,
        };
    }
    async canUseCredit(payer, token, amount) {
        const contract = this.getReadContract();
        return await contract.read.canUseCredit([payer, token, amount]);
    }
    async getFirstSeen(payer) {
        const contract = this.getReadContract();
        return await contract.read.firstSeen([payer]);
    }
    // ═══════════════════════════════════════════════════════════════
    // WRITE METHODS - Intent Lifecycle
    // ═══════════════════════════════════════════════════════════════
    async createIntent(params, servicePreimage) {
        const contract = this.getWriteContract();
        const nonce = (0, intentId_1.getNextNonce)();
        const intentId = (0, intentId_1.generateIntentId)({
            chainId: this.chainId,
            escrowAddress: this.address,
            payer: this.walletClient.account.address,
            provider: params.provider,
            token: params.token,
            amount: params.amount,
            nonce,
        });
        const preimageBytes = (0, commitReveal_1.encodeServicePreimage)(servicePreimage);
        const serviceHash = (0, commitReveal_1.generateServiceHash)({
            chainId: this.chainId,
            escrowAddress: this.address,
            intentId,
            payer: this.walletClient.account.address,
            provider: params.provider,
            token: params.token,
            amount: params.amount,
            preimage: preimageBytes,
        });
        const hash = await contract.write.createIntent([
            params.provider,
            params.token,
            params.amount,
            params.deadlineBlock,
            params.revealDeadline,
            params.fastMode,
            params.reputationMin,
            serviceHash,
            nonce,
            params.erc8004Attestation?.attestationHash || '0x0000000000000000000000000000000000000000000000000000000000000000',
            params.erc8004Attestation?.signature || '0x',
        ]);
        return { hash, intentId };
    }
    async revealIntent(params) {
        const contract = this.getWriteContract();
        return await contract.write.revealIntent([
            params.intentId,
            params.provider,
            params.bond,
            params.salt,
        ]);
    }
    async settle(intentId) {
        const contract = this.getWriteContract();
        return await contract.write.settle([intentId]);
    }
    async finalizeNoReveal(intentId) {
        const contract = this.getWriteContract();
        return await contract.write.finalizeNoReveal([intentId]);
    }
    async openDispute(params) {
        const contract = this.getWriteContract();
        return await contract.write.openDispute([
            params.intentId,
            params.evidenceHash,
        ]);
    }
    async resolveDispute(intentId, outcome, insuranceAmount) {
        const contract = this.getWriteContract();
        return await contract.write.resolveDispute([
            intentId,
            outcome,
            insuranceAmount,
        ]);
    }
    async executeDisputeTimeout(intentId) {
        const contract = this.getWriteContract();
        return await contract.write.executeDisputeTimeout([intentId]);
    }
    async withdrawCredit(intentId) {
        const contract = this.getWriteContract();
        return await contract.write.withdrawCredit([intentId]);
    }
    async grantCredit(payer, token, amount) {
        const contract = this.getWriteContract();
        const hash = await contract.write.grantCredit([payer, token, amount]);
        const creditId = (0, intentId_1.generateIntentId)({
            chainId: this.chainId,
            escrowAddress: this.address,
            payer,
            provider: payer,
            token,
            amount,
            nonce: 0n,
        });
        return { hash, creditId };
    }
    async expireCredit(creditId) {
        const contract = this.getWriteContract();
        return await contract.write.expireCredit([creditId]);
    }
    watchIntentCreated(callback) {
        return this.publicClient.watchContractEvent({
            address: this.address,
            abi: AgentEscrow_json_1.default,
            eventName: 'IntentCreated',
            onLogs: (logs) => {
                logs.forEach((log) => {
                    callback({
                        intentId: log.args.intentId,
                        payer: log.args.payer,
                        provider: log.args.provider,
                        token: log.args.token,
                        amount: log.args.amount,
                    });
                });
            },
        });
    }
}
exports.AgentEscrowClient = AgentEscrowClient;
