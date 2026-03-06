import { keccak256, encodePacked, Hash, Address } from 'viem';

/**
 * Generate intent ID (deterministic, replay-resistant)
 * 
 * Formula: keccak256(chainId, escrowAddress, payer, provider, token, amount, nonce)
 */
export function generateIntentId(params: {
  chainId: number;
  escrowAddress: Address;
  payer: Address;
  provider: Address;
  token: Address;
  amount: bigint;
  nonce: bigint;
}): Hash {
  return keccak256(
    encodePacked(
      ['uint256', 'address', 'address', 'address', 'address', 'uint256', 'uint256'],
      [
        BigInt(params.chainId),
        params.escrowAddress,
        params.payer,
        params.provider,
        params.token,
        params.amount,
        params.nonce,
      ]
    )
  );
}

/**
 * Get next nonce for a payer
 * (In production, query from contract or maintain local counter)
 */
export function getNextNonce(): bigint {
  return BigInt(Date.now());
}
