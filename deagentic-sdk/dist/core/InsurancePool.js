"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.InsurancePoolClient = exports.ClaimStatus = void 0;
const viem_1 = require("viem");
const InsurancePool_json_1 = __importDefault(require("../constants/abis/InsurancePool.json"));
var ClaimStatus;
(function (ClaimStatus) {
    ClaimStatus[ClaimStatus["UNAUTHORIZED"] = 0] = "UNAUTHORIZED";
    ClaimStatus[ClaimStatus["AUTHORIZED"] = 1] = "AUTHORIZED";
    ClaimStatus[ClaimStatus["CLAIMED"] = 2] = "CLAIMED";
    ClaimStatus[ClaimStatus["EXPIRED"] = 3] = "EXPIRED";
})(ClaimStatus || (exports.ClaimStatus = ClaimStatus = {}));
class InsurancePoolClient {
    constructor(address, publicClient, walletClient) {
        this.address = address;
        this.publicClient = publicClient;
        this.walletClient = walletClient;
    }
    getReadContract() {
        return (0, viem_1.getContract)({
            address: this.address,
            abi: InsurancePool_json_1.default,
            client: this.publicClient,
        });
    }
    getWriteContract() {
        if (!this.walletClient) {
            throw new Error('Wallet client required for write operations');
        }
        return (0, viem_1.getContract)({
            address: this.address,
            abi: InsurancePool_json_1.default,
            client: this.walletClient,
        });
    }
    async getPoolBalance(token) {
        const contract = this.getReadContract();
        return await contract.read.poolBalance([token]);
    }
    async getClaim(claimId) {
        const contract = this.getReadContract();
        const claim = await contract.read.claims([claimId]);
        return {
            payer: claim.payer,
            provider: claim.provider,
            token: claim.token,
            requestedAmount: claim.requestedAmount,
            authorizedAt: claim.authorizedAt,
            status: claim.status,
        };
    }
    async getMaxPayerPayout(token) {
        const contract = this.getReadContract();
        return await contract.read.MAX_PAYER_PAYOUT_PER_TOKEN([token]);
    }
    async deposit(token, amount) {
        const contract = this.getWriteContract();
        return await contract.write.deposit([token, amount]);
    }
    async claim(intentId) {
        const contract = this.getWriteContract();
        return await contract.write.claim([intentId]);
    }
    async expireClaim(claimId) {
        const contract = this.getWriteContract();
        return await contract.write.expireClaim([claimId]);
    }
}
exports.InsurancePoolClient = InsurancePoolClient;
