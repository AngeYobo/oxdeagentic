"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.StakeManagerClient = void 0;
const viem_1 = require("viem");
const StakeManager_json_1 = __importDefault(require("../constants/abis/StakeManager.json"));
class StakeManagerClient {
    constructor(address, publicClient, walletClient) {
        this.address = address;
        this.publicClient = publicClient;
        this.walletClient = walletClient;
    }
    getReadContract() {
        return (0, viem_1.getContract)({
            address: this.address,
            abi: StakeManager_json_1.default,
            client: this.publicClient,
        });
    }
    getWriteContract() {
        if (!this.walletClient) {
            throw new Error('Wallet client required for write operations');
        }
        return (0, viem_1.getContract)({
            address: this.address,
            abi: StakeManager_json_1.default,
            client: this.walletClient,
        });
    }
    async getTotalStake(provider, token) {
        const contract = this.getReadContract();
        return await contract.read.totalStake([provider, token]);
    }
    async getLockedStake(provider, token) {
        const contract = this.getReadContract();
        return await contract.read.lockedStake([provider, token]);
    }
    async getAvailableStake(provider, token) {
        const contract = this.getReadContract();
        return await contract.read.availableStake([provider, token]);
    }
    async getIntentLock(intentId) {
        const contract = this.getReadContract();
        const lock = await contract.read.intentLocks([intentId]);
        return {
            provider: lock.provider,
            token: lock.token,
            amount: lock.amount,
            active: lock.active,
        };
    }
    async depositStake(token, amount) {
        const contract = this.getWriteContract();
        return await contract.write.depositStake([token, amount]);
    }
    async withdrawStake(token, amount) {
        const contract = this.getWriteContract();
        return await contract.write.withdrawStake([token, amount]);
    }
    async hasSufficientStake(provider, token, required) {
        const available = await this.getAvailableStake(provider, token);
        return available >= required;
    }
    async getStakeUtilization(provider, token) {
        const total = await this.getTotalStake(provider, token);
        if (total === 0n)
            return 0;
        const locked = await this.getLockedStake(provider, token);
        return Number((locked * 10000n) / total) / 100;
    }
}
exports.StakeManagerClient = StakeManagerClient;
