import { describe, it, expect } from '@jest/globals';
import { generateIntentId, getNextNonce } from '../src/utils/intentId';

describe('Intent ID Utils', () => {
  it('should generate deterministic intent ID', () => {
    const params = {
      chainId: 8453,
      escrowAddress: '0x5FbDB2315678afecb367f032d93F642f64180aa3' as `0x${string}`,
      payer: '0x1111111111111111111111111111111111111111' as `0x${string}`,
      provider: '0x2222222222222222222222222222222222222222' as `0x${string}`,
      token: '0x3333333333333333333333333333333333333333' as `0x${string}`,
      amount: 100n,
      nonce: 123n,
    };

    const id1 = generateIntentId(params);
    const id2 = generateIntentId(params);

    expect(id1).toBe(id2);
    expect(id1).toMatch(/^0x[a-f0-9]{64}$/);
  });

  it('should generate different IDs for different params', () => {
    const baseParams = {
      chainId: 8453,
      escrowAddress: '0x5FbDB2315678afecb367f032d93F642f64180aa3' as `0x${string}`,
      payer: '0x1111111111111111111111111111111111111111' as `0x${string}`,
      provider: '0x2222222222222222222222222222222222222222' as `0x${string}`,
      token: '0x3333333333333333333333333333333333333333' as `0x${string}`,
      amount: 100n,
      nonce: 123n,
    };

    const id1 = generateIntentId(baseParams);
    const id2 = generateIntentId({ ...baseParams, amount: 200n });

    expect(id1).not.toBe(id2);
  });

  it('should generate unique nonces', () => {
    const nonce1 = getNextNonce();
    const nonce2 = getNextNonce();

    expect(typeof nonce1).toBe('bigint');
    expect(typeof nonce2).toBe('bigint');
    expect(nonce2).toBeGreaterThanOrEqual(nonce1);
  });
});
