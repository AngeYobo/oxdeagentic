console.log('\n🧪 Test d\'import du SDK...\n');

try {
  const SDK = require('./dist/index.js');
  
  console.log('✅ SDK importé avec succès\n');
  
  // Test salt generation
  const salt = SDK.generateSalt();
  console.log('📝 Test generateSalt():');
  console.log(`   ${salt.substring(0, 30)}...`);
  console.log('');
  
  // Test nonce
  const nonce = SDK.getNextNonce();
  console.log('📝 Test getNextNonce():');
  console.log(`   ${nonce}`);
  console.log('');
  
  // Test preimage encoding
  const preimage = SDK.encodeServicePreimage({
    description: 'Test service',
    deliverables: ['file1.txt', 'file2.txt'],
  });
  console.log('📝 Test encodeServicePreimage():');
  console.log(`   ${preimage.substring(0, 50)}...`);
  console.log('');
  
  console.log('✅ Tous les tests d\'import réussis\n');
  
} catch (error) {
  console.error('❌ Erreur:', error.message);
  console.error(error.stack);
  process.exit(1);
}
