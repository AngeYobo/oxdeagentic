import { keccak256, encodePacked, Hash, Address, Hex, stringToHex, toHex, hexToString } from 'viem';

/**
 * Domain separator for service hash
 */
export const SERVICE_HASH_DOMAIN = 'DEAI_SERVICE_V1';

/**
 * Service preimage structure
 */
export interface ServicePreimage {
  description: string;
  deliverables: string[];
  metadata?: Record<string, unknown>;
}

/**
 * Generate service hash for commit-reveal
 * 
 * @param params Service hash parameters
 * @returns Service hash
 */
export function generateServiceHash(params: {
  chainId: number;
  escrowAddress: Address;
  intentId: Hash;
  payer: Address;
  provider: Address;
  token: Address;
  amount: bigint;
  preimage: string | Hex;
}): Hash {
  const preimageBytes: Hex = typeof params.preimage === 'string' 
    ? stringToHex(params.preimage)
    : params.preimage;

  return keccak256(
    encodePacked(
      ['string', 'uint256', 'address', 'bytes32', 'address', 'address', 'address', 'uint256', 'bytes'],
      [
        SERVICE_HASH_DOMAIN,
        BigInt(params.chainId),
        params.escrowAddress,
        params.intentId,
        params.payer,
        params.provider,
        params.token,
        params.amount,
        preimageBytes,
      ]
    )
  );
}

/**
 * Generate random salt for commit-reveal
 */
export function generateSalt(): Hash {
  const randomBytes = new Uint8Array(32);
  crypto.getRandomValues(randomBytes);
  return toHex(randomBytes);
}

/**
 * Encode service preimage to bytes
 */
export function encodeServicePreimage(preimage: ServicePreimage): Hex {
  const json = JSON.stringify(preimage);
  return stringToHex(json);
}

/**
 * Decode service preimage from bytes
 */
export function decodeServicePreimage(encoded: Hex): ServicePreimage {
  try {
    const json = hexToString(encoded);
    return JSON.parse(json);
  } catch {
    const bytes = encoded.slice(2).match(/.{1,2}/g)?.map(byte => parseInt(byte, 16)) || [];
    const uint8Array = new Uint8Array(bytes);
    const decoder = new TextDecoder('utf-8');
    const json = decoder.decode(uint8Array);
    return JSON.parse(json);
  }
}
