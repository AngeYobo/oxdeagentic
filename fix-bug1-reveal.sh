#!/bin/bash
set -e

echo "🔧 Bug #1: revealIntent..."

# Backup
cp src/AgentEscrow.sol src/AgentEscrow.sol.backup-bug1
cp src/interfaces/IAgentEscrow.sol src/interfaces/IAgentEscrow.sol.backup-bug1

# Fix signature dans interface (simple replace)
cat > /tmp/new_reveal_sig.txt << 'EOF'
    function revealIntent(
        bytes32 intentId,
        address provider,
        uint96 bond,
        bytes32 salt
    ) external;
EOF

# Trouver début et fin de la signature dans l'interface
START=$(grep -n "function revealIntent" src/interfaces/IAgentEscrow.sol | cut -d: -f1)
END=$(awk "NR>$START && /external;/ {print NR; exit}" src/interfaces/IAgentEscrow.sol)

# Remplacer
sed -i "${START},${END}d" src/interfaces/IAgentEscrow.sol
sed -i "${START}r /tmp/new_reveal_sig.txt" src/interfaces/IAgentEscrow.sol

# Fix signature dans implémentation
sed -i '/function revealIntent(/,/external nonReentrant {/{
    /address token,/d
    /uint96 amount,/d
}' src/AgentEscrow.sol

# Fix hash calculation
sed -i 's/keccak256(abi.encodePacked(\n[[:space:]]*provider,\n[[:space:]]*token,\n[[:space:]]*amount,/keccak256(abi.encodePacked(\n            provider,\n            intent.token,\n            intent.amount,/' src/AgentEscrow.sol

echo "✅ Bug #1 corrigé"

