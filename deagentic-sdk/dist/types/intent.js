"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.IntentFlags = exports.IntentState = void 0;
/**
 * Intent States (matching Solidity enum)
 */
var IntentState;
(function (IntentState) {
    IntentState[IntentState["NONE"] = 0] = "NONE";
    IntentState[IntentState["CREATED"] = 1] = "CREATED";
    IntentState[IntentState["REVEALED"] = 2] = "REVEALED";
    IntentState[IntentState["DISPUTED"] = 3] = "DISPUTED";
    IntentState[IntentState["SETTLED_PROVIDER"] = 4] = "SETTLED_PROVIDER";
    IntentState[IntentState["SETTLED_PAYER"] = 5] = "SETTLED_PAYER";
    IntentState[IntentState["SETTLED_SPLIT"] = 6] = "SETTLED_SPLIT";
    IntentState[IntentState["NO_REVEAL_FINALIZED"] = 7] = "NO_REVEAL_FINALIZED";
})(IntentState || (exports.IntentState = IntentState = {}));
/**
 * Intent flags
 */
exports.IntentFlags = {
    FAST_MODE: 1 << 0, // 0x01
    ERC8004_USED: 1 << 1, // 0x02
};
