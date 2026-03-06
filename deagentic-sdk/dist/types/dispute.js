"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DisputeOutcome = exports.DisputeStatus = void 0;
/**
 * Dispute status (matching Solidity enum)
 */
var DisputeStatus;
(function (DisputeStatus) {
    DisputeStatus[DisputeStatus["NONE"] = 0] = "NONE";
    DisputeStatus[DisputeStatus["OPEN"] = 1] = "OPEN";
    DisputeStatus[DisputeStatus["RESOLVED_PAYER"] = 2] = "RESOLVED_PAYER";
    DisputeStatus[DisputeStatus["RESOLVED_PROVIDER"] = 3] = "RESOLVED_PROVIDER";
    DisputeStatus[DisputeStatus["RESOLVED_SPLIT"] = 4] = "RESOLVED_SPLIT";
    DisputeStatus[DisputeStatus["TIMEOUT_SPLIT"] = 5] = "TIMEOUT_SPLIT";
})(DisputeStatus || (exports.DisputeStatus = DisputeStatus = {}));
/**
 * Dispute outcome for resolution
 */
var DisputeOutcome;
(function (DisputeOutcome) {
    DisputeOutcome[DisputeOutcome["PAYER_WIN"] = 0] = "PAYER_WIN";
    DisputeOutcome[DisputeOutcome["PROVIDER_WIN"] = 1] = "PROVIDER_WIN";
    DisputeOutcome[DisputeOutcome["SPLIT_50_50"] = 2] = "SPLIT_50_50";
})(DisputeOutcome || (exports.DisputeOutcome = DisputeOutcome = {}));
