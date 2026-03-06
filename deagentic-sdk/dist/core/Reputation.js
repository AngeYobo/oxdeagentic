"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ReputationClient = void 0;
const viem_1 = require("viem");
const ReputationRegistry_json_1 = __importDefault(require("../constants/abis/ReputationRegistry.json"));
/**
 * ReputationRegistry client for reputation queries
 */
class ReputationClient {
    constructor(address, publicClient, walletClient) {
        this.address = address;
        this.publicClient = publicClient;
        this.walletClient = walletClient;
    }
    getReadContract() {
        return (0, viem_1.getContract)({
            address: this.address,
            abi: ReputationRegistry_json_1.default,
            client: this.publicClient,
        });
    }
    // ═══════════════════════════════════════════════════════════════
    // READ METHODS
    // ═══════════════════════════════════════════════════════════════
    async getScore(provider) {
        const contract = this.getReadContract();
        const score = await contract.read.scores([provider]);
        return Number(score);
    }
    async getCurrentEpoch() {
        const contract = this.getReadContract();
        return await contract.read.getCurrentEpoch();
    }
    async getCounterpartyGains(provider, payer, epochStart) {
        const contract = this.getReadContract();
        return await contract.read.counterpartyGains([provider, payer, epochStart]);
    }
    // ═══════════════════════════════════════════════════════════════
    // HELPER METHODS
    // ═══════════════════════════════════════════════════════════════
    async meetsThreshold(provider, threshold) {
        const score = await this.getScore(provider);
        return score >= threshold;
    }
    async getReputationPercentage(provider) {
        const score = await this.getScore(provider);
        return (score / 1000) * 100;
    }
}
exports.ReputationClient = ReputationClient;
