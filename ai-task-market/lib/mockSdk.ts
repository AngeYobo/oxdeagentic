// Mock SDK pour tester l'UI sans contrats déployés

export class MockAgentEscrowClient {
  async createIntent(params: any, preimage: any) {
    console.log('Mock createIntent:', params, preimage);
    
    // Simuler un délai réseau
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    return {
      hash: '0x' + Math.random().toString(16).slice(2, 66),
      intentId: '0x' + Math.random().toString(16).slice(2, 66),
    };
  }
  
  async getIntent(intentId: string) {
    return {
      payer: '0x1234567890123456789012345678901234567890',
      provider: '0x9876543210987654321098765432109876543210',
      token: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
      amount: 100_000000n,
      deadlineBlock: 1000000n,
      revealDeadline: BigInt(Date.now() / 1000 + 86400),
      revealTimestamp: 0n,
      reputationMin: 500,
      flags: 0,
      state: 1, // CREATED
      serviceHash: '0x' + '0'.repeat(64),
      nonce: 1n,
    };
  }
}

export const MOCK_MODE = true;
