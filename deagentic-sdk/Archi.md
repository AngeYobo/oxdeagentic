deagentic-sdk/
├── src/
│   ├── core/
│   │   ├── AgentEscrow.ts      # Main escrow client
│   │   ├── StakeManager.ts     # Stake operations
│   │   ├── InsurancePool.ts    # Insurance claims
│   │   └── Reputation.ts       # Reputation queries
│   ├── utils/
│   │   ├── commitReveal.ts     # Commit-reveal helpers
│   │   ├── intentId.ts         # Intent ID generation
│   │   ├── signing.ts          # EIP-712 signing
│   │   └── erc8004.ts          # ERC-8004 attestations
│   ├── types/
│   │   ├── intent.ts           # Intent types
│   │   ├── dispute.ts          # Dispute types
│   │   └── contracts.ts        # Contract ABIs
│   ├── constants/
│   │   └── addresses.ts        # Deployed addresses
│   └── index.ts                # Main export
├── test/
│   ├── commitReveal.test.ts
│   ├── intentFlow.test.ts
│   └── dispute.test.ts
├── examples/
│   ├── createIntent.ts
│   ├── revealAndSettle.ts
│   └── handleDispute.ts
├── package.json
├── tsconfig.json
└── README.md