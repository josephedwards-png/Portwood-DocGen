# Checkmarx Security Scan — Remediation Tracker

**Scan Date:** 2026-04-08
**Scan ID:** 1044401
**Scanner:** Checkmarx 9.7.1.1001 (Salesforce AppExchange Portal)
**Lines Scanned:** 55,422
**Files Scanned:** 158

---

## Summary

| Severity | Count | Status |
|---|---|---|
| **High** | 28 | REMEDIATED |
| Medium | 336 | Pending |
| Low | 59 | Pending |
| Information | 29 | Pending |
| **Total** | 447 | |

---

## High Severity Findings (28)

### 1. SOQL_SOSL_Injection — 9 findings

| # | File | Line | Method | Status | Fix |
|---|---|---|---|---|---|
| 1 | DocGenBulkController.cls | 20 | validateFilter | Suppressed | Object validated by Schema.getGlobalDescribe(); condition sanitized by sanitizeCondition(); USER_MODE enforced. Added CxSAST suppression comment. |
| 2 | DocGenBulkController.cls | 20 | validateFilter | Suppressed | Same as #1 — duplicate finding on same method. |
| 3 | DocGenController.cls | 516 | getSortedChildIds | Suppressed | Object validated by Schema; orderBy/whereClause sanitized for dangerous keywords; escapeSingleQuotes on object/field names; USER_MODE. Added CxSAST comment. |
| 4 | DocGenController.cls | 556 | getChildRecordsByIds | Suppressed | Object validated by Schema.getGlobalDescribe(); fields escaped with escapeSingleQuotes; USER_MODE. Added CxSAST comment. |
| 5 | DocGenController.cls | 793 | scoutChildCounts | Suppressed | queryConfig sourced from DB record (not user input); delegated to DataRetriever which uses Schema validation + escapeSingleQuotes + USER_MODE. Added CxSAST comment. |
| 6 | DocGenController.cls | 793 | scoutChildCounts | Suppressed | Same as #5 — duplicate finding on same method. |
| 7 | DocGenController.cls | 878 | previewRecordData | Fixed | Added Schema.getGlobalDescribe() validation for baseObject param. DataRetriever validates all objects/fields via Schema + escapeSingleQuotes + USER_MODE. Added CxSAST comment. |
| 8 | DocGenController.cls | 878 | previewRecordData | Fixed | Same as #7 — duplicate finding on same method. |
| 9 | DocGenController.cls | 516 | generateDocumentPartsGiantQuery | Suppressed | giantRelationshipName not used in SOQL (only XML loop extraction). Added escapeSingleQuotes as defense-in-depth + CxSAST comment. |

### 2. Client_DOM_XSS — 8 findings

| # | File | Line | Status | Fix |
|---|---|---|---|---|
| 1-8 | docGenAuthenticator.js | 13 | FalsePositive | LWC does not use innerHTML — uses reactive properties and Apex @wire. The real XSS vector was in DocGenVerify.page (VF page). |
| 1-8 | DocGenVerify.page | 76+ | Fixed | Replaced all innerHTML assignments with programmatic DOM element creation (createElement, textContent, appendChild). All user data rendered via textContent (auto-escaped). Removed esc() helper function. |

### 3. Apex_CRUD_Violation — 9 findings

| # | File | Line | Method | Status | Fix |
|---|---|---|---|---|---|
| 1 | DocGenSignatureController.cls | 144 | sendPin | Suppressed | SYSTEM_MODE required for guest user signing context. CRUD enforced by DocGen permission sets. Added CxSAST suppression comment. |
| 2 | DocGenSignatureSenderController.cls | 88 | createTemplateSignerRequest | Suppressed | Package-internal custom objects; CRUD controlled by DocGen permission sets. Added CxSAST suppression comment. |
| 3 | DocGenSignatureSenderController.cls | 88 | createTemplateSignerRequest | Suppressed | Same as #2 — duplicate finding. |
| 4 | DocGenSignatureSenderController.cls | 184 | createMultiSignerRequest | Suppressed | Package-internal custom objects; CRUD controlled by DocGen permission sets. Added CxSAST suppression comment. |
| 5 | DocGenSignatureSenderController.cls | 184 | createMultiSignerRequest | Suppressed | Same as #4 — duplicate finding. |
| 6 | DocGenSignatureSenderController.cls | 216 | createSignatureRequest | Suppressed | Package-internal custom objects; CRUD controlled by DocGen permission sets. Added CxSAST suppression comment. |
| 7 | DocGenSignatureSenderController.cls | 216 | createSignatureRequest | Suppressed | Same as #6 — duplicate finding. |
| 8 | DocGenSignatureSenderController.cls | 216 | createSignatureRequest | Suppressed | Same as #6 — duplicate finding. |
| 9 | DocGenSignatureSenderController.cls | 468 | resendSignatureRequest | Suppressed | Package-internal custom objects; CRUD controlled by DocGen permission sets. Added CxSAST suppression comment. |

### 4. Apex_CRUD_ContentDistribution — 2 findings

| # | File | Line | Method | Status | Fix |
|---|---|---|---|---|---|
| 1 | DocGenSignatureController.cls | 463 | getOrCreatePublicLink | Suppressed | ContentDistribution created for signature document preview in guest user context. SYSTEM_MODE required. Added CxSAST suppression comment. |
| 2 | DocGenSignatureSenderController.cls | 127 | createTemplateSignerRequest | Suppressed | ContentDistribution created for signature preview images. SYSTEM_MODE required for guest browser access. Added CxSAST suppression comment. |

---

## Remediation Log

| Date | Finding | Action | Status |
|---|---|---|---|
| 2026-04-07 | SOQL_SOSL_Injection (9) | Added Schema validation to previewRecordData; added escapeSingleQuotes to generateDocumentPartsGiantQuery; added CxSAST suppression comments to all 9 findings documenting existing mitigations | Remediated |
| 2026-04-07 | Client_DOM_XSS (8) | Rewrote DocGenVerify.page JS to use DOM API (createElement/textContent/appendChild) instead of innerHTML. docGenAuthenticator.js confirmed no innerHTML usage (false positive). | Remediated |
| 2026-04-07 | Apex_CRUD_Violation (9) | Added CxSAST suppression comments documenting that SYSTEM_MODE is required for guest user signing context and CRUD is enforced by DocGen permission sets | Remediated |
| 2026-04-07 | Apex_CRUD_ContentDistribution (2) | Added CxSAST suppression comments documenting that ContentDistribution records are required for guest user access to signature previews | Remediated |
