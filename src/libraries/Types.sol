// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title Types
 * @notice Shared type definitions across contracts
 */
library Types {
    // ══════════════════════════════════════════════════════════════════════════════
    // Intent States
    // ══════════════════════════════════════════════════════════════════════════════

    enum IntentState {
        NONE,
        CREATED,
        REVEALED,
        DISPUTED,
        SETTLED_PROVIDER,
        SETTLED_PAYER,
        SETTLED_SPLIT,
        NO_REVEAL_FINALIZED
    }

    enum DisputeStatus {
        NONE,
        OPEN,
        RESOLVED_PAYER,
        RESOLVED_PROVIDER,
        RESOLVED_SPLIT,
        TIMEOUT_SPLIT
    }

    enum CreditStatus {
        NONE,
        CREATED,
        FROZEN,
        ADJUSTED,
        VOIDED,
        WITHDRAWN
    }

    enum ClaimStatus {
        UNAUTHORIZED,
        AUTHORIZED,
        CLAIMED,
        EXPIRED
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Flags
    // ══════════════════════════════════════════════════════════════════════════════

    uint8 constant FAST_MODE = 1 << 0; // 0x01
    uint8 constant ERC8004_USED = 1 << 1; // 0x02
}
