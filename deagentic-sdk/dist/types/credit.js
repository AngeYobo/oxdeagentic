"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CreditStatus = void 0;
/**
 * Credit status (FastMode credits)
 */
var CreditStatus;
(function (CreditStatus) {
    CreditStatus[CreditStatus["NONE"] = 0] = "NONE";
    CreditStatus[CreditStatus["CREATED"] = 1] = "CREATED";
    CreditStatus[CreditStatus["FROZEN"] = 2] = "FROZEN";
    CreditStatus[CreditStatus["ADJUSTED"] = 3] = "ADJUSTED";
    CreditStatus[CreditStatus["VOIDED"] = 4] = "VOIDED";
    CreditStatus[CreditStatus["WITHDRAWN"] = 5] = "WITHDRAWN";
})(CreditStatus || (exports.CreditStatus = CreditStatus = {}));
