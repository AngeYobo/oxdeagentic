/**
 * Example: Create an Intent
 * 
 * This example shows how to create an intent with the DeAgentic SDK.
 * 
 * Usage:
 *   ts-node examples/createIntent.ts
 */

import { AgentEscrowClient, ServicePreimage } from '../src';
import { createPublicClient, createWalletClient, http } from 'viem';
import { base } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';

async function main() {
  // ⚠️  REPLACE THESE WITH YOUR ACTUAL VALUES
  const config = {
    privateKey: '0x0000000000000000000000000000000000000000000000000000000000000000' as `0x${string}`,
    escrowAddress: '0x0000000000000000000000000000000000000000' as `0x${string}`,
    providerAddress: '0x0000000000000000000000000000000000000000' as `0x${string}`,
    usdcAddress: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913' as `0x${string}`, // Base USDC
  };

  // Create account from private key
  const account = privateKeyToAccount(config.privateKey);
  
  // Create viem clients
  // @ts-ignore // Ignore Viem Base chain type mismatch (false positive)
  const publicClient = createPublicClient({
    chain: base,
    transport: http(),
  });

  const walletClient = createWalletClient({
    chain: base,
    transport: http(),
    account,
  });

  // Initialize SDK
  // Note: IDE may show type error for Base chain's deposit tx type
  // This is a false positive - build compiles successfully
  const escrow = new AgentEscrowClient(
    config.escrowAddress,
    publicClient,
    walletClient,
  );

  console.log('Creating intent...');
  console.log('Payer:', account.address);
  console.log('Provider:', config.providerAddress);

  // Get current block for deadline
  const currentBlock = await publicClient.getBlockNumber();
  const deadlineBlock = currentBlock + 1000n;
  
  // Service preimage
  const servicePreimage: ServicePreimage = {
    description: 'Train GPT-4 fine-tune on custom dataset',
    deliverables: [
      'fine_tuned_model.safetensors',
      'training_metrics.json',
      'validation_results.csv',
    ],
    metadata: {
      dataset_size: '10k_samples',
      expected_accuracy: '95%',
    },
  };
  
  // Create intent
  const { hash, intentId } = await escrow.createIntent(
    {
      provider: config.providerAddress,
      token: config.usdcAddress,
      amount: 100_000000n, // 100 USDC (6 decimals)
      deadlineBlock,
      revealDeadline: BigInt(Math.floor(Date.now() / 1000) + 86400), // 24h from now
      fastMode: false,
      reputationMin: 500,
    },
    servicePreimage
  );

  console.log('\n✅ Intent created!');
  console.log('Transaction hash:', hash);
  console.log('Intent ID:', intentId);
  console.log('Deadline block:', deadlineBlock.toString());

  // Query intent details
  const intent = await escrow.getIntent(intentId);
  console.log('\n📋 Intent details:');
  console.log('  Payer:', intent.payer);
  console.log('  Provider:', intent.provider);
  console.log('  Token:', intent.token);
  console.log('  Amount:', intent.amount.toString());
  console.log('  State:', intent.state);
  
  console.log('\n✅ Example completed successfully');
}

// Run example
main().catch((error) => {
  console.error('\n❌ Error:', error);
  throw error;
});
