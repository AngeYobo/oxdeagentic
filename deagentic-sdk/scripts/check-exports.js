const fs = require('fs');
const path = require('path');

console.log('\n🔍 Vérification des exports...\n');

const distIndexPath = path.join(__dirname, '../dist/index.js');

if (!fs.existsSync(distIndexPath)) {
  console.error('❌ dist/index.js not found. Run pnpm build first.');
  process.exit(1);
}

try {
  const exported = require(distIndexPath);
  
  console.log('✅ Exports disponibles:');
  console.log('');
  
  const expectedExports = [
    'AgentEscrowClient',
    'StakeManagerClient', 
    'InsurancePoolClient',
    'ReputationClient',
    'generateServiceHash',
    'generateIntentId',
    'generateSalt',
    'DEPLOYED_ADDRESSES',
    'getAddresses',
  ];
  
  let missing = 0;
  
  expectedExports.forEach(name => {
    if (exported[name]) {
      console.log(`   ✅ ${name}`);
    } else {
      console.log(`   ❌ ${name} - MANQUANT`);
      missing++;
    }
  });
  
  console.log('');
  
  if (missing === 0) {
    console.log('✅ Tous les exports attendus sont présents\n');
  } else {
    console.log(`❌ ${missing} exports manquants\n`);
  }
  
} catch (error) {
  console.error('❌ Erreur:', error.message);
  process.exit(1);
}
