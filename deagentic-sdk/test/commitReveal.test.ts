import { describe, it, expect } from '@jest/globals';
import {
  generateServiceHash,
  generateSalt,
  encodeServicePreimage,
  decodeServicePreimage,
} from '../src/utils/commitReveal';

describe('Commit-Reveal Utils', () => {
  it('should generate service hash correctly', () => {
    const hash = generateServiceHash({
      chainId: 8453,
      escrowAddress: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
      intentId: '0x1234567890123456789012345678901234567890123456789012345678901234',
      payer: '0x1111111111111111111111111111111111111111',
      provider: '0x2222222222222222222222222222222222222222',
      token: '0x3333333333333333333333333333333333333333',
      amount: 100n,
      preimage: 'test service delivery',
    });

    expect(hash).toMatch(/^0x[a-f0-9]{64}$/);
  });

  it('should generate unique salts', () => {
    const salt1 = generateSalt();
    const salt2 = generateSalt();

    expect(salt1).toMatch(/^0x[a-f0-9]{64}$/);
    expect(salt2).toMatch(/^0x[a-f0-9]{64}$/);
    expect(salt1).not.toBe(salt2);
  });

  it('should encode and decode preimage correctly', () => {
    const original = {
      description: 'AI model training',
      deliverables: ['model.pth', 'metrics.json'],
      metadata: { version: '1.0' },
    };

    const encoded = encodeServicePreimage(original);
    expect(encoded).toMatch(/^0x[a-f0-9]+$/);

    const decoded = decodeServicePreimage(encoded);
    expect(decoded).toEqual(original);
  });
});
