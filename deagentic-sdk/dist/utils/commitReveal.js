"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SERVICE_HASH_DOMAIN = void 0;
exports.generateServiceHash = generateServiceHash;
exports.generateSalt = generateSalt;
exports.encodeServicePreimage = encodeServicePreimage;
exports.decodeServicePreimage = decodeServicePreimage;
const viem_1 = require("viem");
/**
 * Domain separator for service hash
 */
exports.SERVICE_HASH_DOMAIN = 'DEAI_SERVICE_V1';
/**
 * Generate service hash for commit-reveal
 *
 * @param params Service hash parameters
 * @returns Service hash
 */
function generateServiceHash(params) {
    const preimageBytes = typeof params.preimage === 'string'
        ? (0, viem_1.stringToHex)(params.preimage)
        : params.preimage;
    return (0, viem_1.keccak256)((0, viem_1.encodePacked)(['string', 'uint256', 'address', 'bytes32', 'address', 'address', 'address', 'uint256', 'bytes'], [
        exports.SERVICE_HASH_DOMAIN,
        BigInt(params.chainId),
        params.escrowAddress,
        params.intentId,
        params.payer,
        params.provider,
        params.token,
        params.amount,
        preimageBytes,
    ]));
}
/**
 * Generate random salt for commit-reveal
 */
function generateSalt() {
    const randomBytes = new Uint8Array(32);
    crypto.getRandomValues(randomBytes);
    return (0, viem_1.toHex)(randomBytes);
}
/**
 * Encode service preimage to bytes
 */
function encodeServicePreimage(preimage) {
    const json = JSON.stringify(preimage);
    return (0, viem_1.stringToHex)(json);
}
/**
 * Decode service preimage from bytes
 */
function decodeServicePreimage(encoded) {
    try {
        const json = (0, viem_1.hexToString)(encoded);
        return JSON.parse(json);
    }
    catch {
        const bytes = encoded.slice(2).match(/.{1,2}/g)?.map(byte => parseInt(byte, 16)) || [];
        const uint8Array = new Uint8Array(bytes);
        const decoder = new TextDecoder('utf-8');
        const json = decoder.decode(uint8Array);
        return JSON.parse(json);
    }
}
