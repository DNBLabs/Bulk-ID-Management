# PRD: Task 3 — Provisioning CSV contract module

**Normative glossary:** [CONTEXT.md](../../../CONTEXT.md). **Parent product PRD:** [PRD.md](../../PRD.md). **Implementation slice:** [IMPLEMENTATION-PLAN.md](../../IMPLEMENTATION-PLAN.md) — Task 3 only.

**Design references:** [HLD.md](../../Design/HLD.md), [IDD.md](../../Design/IDD.md), [SEC.md](../../Design/SEC.md). **Background only:** [init-project.txt](../../init-project.txt).

**Issue tracker:** Published as [DNBLabs/Bulk-ID-Management#2](https://github.com/DNBLabs/Bulk-ID-Management/issues/2) with the **`ready-for-agent`** label.

---

## Problem Statement

The **BulkIdentityManagement** module scaffold exists (Task 1) and the README points operators to **CONTEXT.md** (Task 2), but there is no way to turn a provisioning CSV file into validated **provisioning row** objects. Downstream work—**Name mapping**, **Identity derivation**, **IT department rule**, and **Apply** orchestration—needs a single, testable boundary that enforces the **Provisioning CSV format** contract before any **Microsoft Graph** calls. Without Task 3, contributors cannot run deterministic **CI validation gates** on CSV behavior, and operators risk starting **apply** against malformed files with unclear failures.

## Solution

Implement a **Provisioning CSV contract** deep module inside **BulkIdentityManagement**: a public **`Import-ProvisioningCsv`** command that reads a file path, validates encoding, headers, and row data per **CONTEXT**, and either **throws a terminating error** (fail-closed) or outputs **provisioning row** objects to the pipeline. The command encapsulates UTF-8 handling (including optional BOM), RFC-style comma-separated parsing, header rules, row materialization (core columns plus header-gated optionals), and physical line numbers for errors and **`SourceLineNumber`** on each row. No **Name mapping**, **Identity derivation**, Graph calls, or orchestration belong in this slice.

## User Stories

1. As an **identity operator**, I want to load a CSV with required columns **FirstName**, **LastName**, and **Department**, so that every **provisioning row** has a minimum contract before **apply**.
2. As an **identity operator**, I want missing required headers to fail before any row is processed, so that I never start **apply** against a malformed file.
3. As an **identity operator**, I want validation errors to name the **physical file line number**, so that I can fix the same row Excel or my editor shows.
4. As an **identity operator**, I want UTF-8 files with an optional UTF-8 BOM to work, so that exports from common editors load without manual re-encoding.
5. As an **identity operator**, I want invalid UTF-8 byte sequences to fail with a clear encoding error, so that mis-encoded files do not silently corrupt names.
6. As an **identity operator**, I want comma-separated values with RFC-style quoting, so that commas inside quoted name fields parse correctly.
7. As an **identity operator**, I want only comma delimiters supported, so that semicolon-locale exports fail clearly instead of being misread.
8. As an **identity operator**, I want required data cells to be non-empty after trimming whitespace, so that incomplete rows are rejected before **apply**.
9. As an **identity operator**, I want a blank optional override cell to mean “use defaults later”, so that I can keep optional columns in a template without filling every row.
10. As an **identity operator**, I want completely empty data rows skipped, so that trailing blank lines from Excel do not create fake users.
11. As an **identity operator**, I want a file with no valid data rows after skips to fail, so that I do not run **apply** on a header-only file by mistake.
12. As an **identity operator**, I want unknown extra columns in my spreadsheet ignored, so that helper columns do not break import.
13. As an **identity operator**, I want duplicate header names after trim to fail the import, so that ambiguous columns do not pick the wrong **Department**.
14. As an **identity operator**, I want header names matched case-sensitively to **FirstName**, **LastName**, **Department**, so that documentation and samples stay aligned with the file I prepare.
15. As an **identity operator**, I want header cells trimmed before matching, so that a stray space in ` Department` does not break validation.
16. As an **identity operator**, I want string values on each **provisioning row** trimmed at import time, so that downstream modules do not repeat whitespace cleanup.
17. As an **identity operator**, I want each **provisioning row** to include **SourceLineNumber**, so that batch reports can point back to my CSV line.
18. As an **identity operator**, I want optional **MailNickname** and **UserPrincipalName** columns honored only when present in the header, so that a minimal three-column file stays simple.
19. As an **identity operator**, I want reserved optional columns **GivenName**, **Surname**, and **DisplayName** supported the same way when present in the header, so that future overrides do not require a new import contract.
20. As a **contributor**, I want **`Import-ProvisioningCsv`** exported from **BulkIdentityManagement**, so that orchestration and tests share one entry point.
21. As a **contributor**, I want import failures to throw terminating errors with no pipeline output, so that callers fail closed like **CONTEXT** requires.
22. As a **contributor**, I want successful import to write **provisioning row** objects to the pipeline in file order, so that batch processing preserves operator intent.
23. As a **contributor**, I want **Pester** tests that cover good CSV, bad headers, encoding failures, and quoted fields, so that **CI validation gates** protect the contract without **Microsoft Graph**.
24. As a **security reviewer**, I want Task 3 to perform no **Apply** or Graph operations, so that default CI needs no tenant credentials for CSV tests.
25. As a **maintainer**, I want CSV logic isolated in a deep module with a narrow public surface, so that Tasks 4–6 can depend on stable row objects without re-parsing files.
26. As a **developer**, I want private helpers for UTF-8 reading, header validation, and row materialization kept internal, so that tests target **`Import-ProvisioningCsv`** behavior not internal names.
27. As an **identity operator**, I want parse failures (e.g. unclosed quotes) to fail the entire import with an actionable message, so that partial rows are never emitted silently.
28. As an **identity operator**, I want a missing required header to fail even if some data rows look valid, so that validation order is headers-first.
29. As a **contributor**, I want test fixtures as small UTF-8 CSV files or here-strings in **Pester**, so that edge cases are reproducible in CI.
30. As a **maintainer**, I want **PSScriptAnalyzer**-clean public functions, so that Task 3 does not regress analyzer gates when wired into CI later.
31. As a **contributor**, I want module import for CSV tests to avoid requiring a live Graph session, so that deterministic tests stay fast and offline.
32. As an **identity operator**, I want wrong-case headers like `firstname` rejected, so that I fix exports to match documented column spellings.
33. As an **identity operator**, I want whitespace-only **LastName** on a data row to fail the import with a line number, so that I cannot provision users without surnames.
34. As a **contributor**, I want acceptance criteria from the implementation plan satisfied, so that Task 3 can be marked complete without starting Task 4.
35. As a **stakeholder**, I want this PRD published with **`ready-for-agent`**, so that implementation can proceed without re-grilling CSV decisions already captured in **CONTEXT**.

## Implementation Decisions

### Modules to build or modify

| Module / unit | Role | Public surface |
|---------------|------|----------------|
| **Provisioning CSV contract** | Deep module: read file, validate **Provisioning CSV format**, materialize **provisioning row** objects | **`Import-ProvisioningCsv -Path <string>`** |
| **BulkIdentityManagement** (host) | Wire public function into manifest exports and root module; no Graph calls at import time for CSV code paths | Export **`Import-ProvisioningCsv`** via **FunctionsToExport** |
| **Private CSV helpers** (optional split) | UTF-8 stream read (BOM-aware), header validation, RFC CSV parse, row materialization, error message formatting | Not exported; implementation detail |

**Recommended layout:** public function under the module’s public folder pattern; private helpers in a private folder or sibling scripts dot-sourced from the root module—match existing repo conventions from Task 1 without introducing a second top-level module name.

### **`Import-ProvisioningCsv` contract**

- **Parameter:** **`-Path`** (mandatory)—filesystem path to the CSV; standard PowerShell parameter validation for missing file is acceptable before contract validation.
- **Success:** writes one **provisioning row** per non-skipped data row to the success pipeline, in file order.
- **Failure:** **terminating throw**; **no** rows on the pipeline (encoding, parse, header, duplicate header, zero rows, required cell empty, etc.).
- **No** `-WhatIf`, Graph, or tenant parameters in Task 3.

### **Provisioning row object shape**

Each emitted row is a structured object (e.g. **PSCustomObject**) with:

| Property | Always present | Notes |
|----------|----------------|-------|
| **SourceLineNumber** | Yes | **1-based physical line** in source file |
| **FirstName** | Yes | Trimmed non-empty string |
| **LastName** | Yes | Trimmed non-empty string |
| **Department** | Yes | Trimmed non-empty string |
| **MailNickname** | Only if header column exists and cell non-empty after trim | Omit property when column absent from header or cell blank |
| **UserPrincipalName** | Same rule | Same |
| **GivenName**, **Surname**, **DisplayName** | Same rule (reserved overrides) | Same |

No placeholder properties for optionals when the header column is absent. No properties for unknown CSV columns.

### **Header and parsing rules** (from **CONTEXT** / grill session)

- **Delimiter:** comma only; no semicolon/tab auto-detection.
- **Quoting:** RFC-style (quoted fields, commas inside quotes, escaped quotes).
- **Encoding:** UTF-8 only; BOM allowed; invalid UTF-8 sequences fail entire import.
- **Headers:** trim each header cell; case-sensitive match to canonical names; required set **FirstName**, **LastName**, **Department**; duplicate canonical names after trim → fail; unknown columns ignored.
- **Data rows:** skip row if every cell empty/whitespace after trim; if zero rows remain → fail (“no provisioning rows”).
- **Required cells:** non-empty after trim or fail entire import with physical line number.
- **Optional cells:** blank/whitespace → property omitted (not an override).

### **Validation order**

1. Resolve and read file as UTF-8 (fail encoding).
2. Parse CSV structure (fail parse).
3. Validate header row (fail before iterating data for missing/duplicate headers).
4. Iterate data rows: skip all-empty; validate required cells; materialize rows.
5. Fail if zero materialized rows.

### **Dependencies and isolation**

- **Task 1** module scaffold and manifest exist; Task 3 adds first exported functions.
- Do **not** import or call **Microsoft.Graph** in CSV implementation or CSV **Pester** tests.
- Do **not** implement **Name mapping**, **Identity derivation**, **IT department rule**, **Graph gateway**, orchestration, entry script, sample CSV (Task 16), or README runbook changes beyond what Task 3 strictly needs.

### **Error messages**

- Actionable text: what failed, which rule, and **line number** (physical file line) for row-level failures; header failures may cite line **1** or “header row”.
- Do not emit partial row sets on failure.

### **No ADR required**

CSV contract decisions are normative in **CONTEXT.md**; no separate ADR unless implementation discovers a hard-to-reverse parser choice worth documenting later.

## Testing Decisions

### What makes a good test

- Assert **observable behavior** of **`Import-ProvisioningCsv`**: thrown errors vs row count, property presence/absence, trimmed values, **SourceLineNumber**, and message content where stable.
- Avoid asserting private function names, internal parse algorithm, or that a specific underlying cmdlet was called unless that is the chosen stable implementation and documented.
- Use temporary CSV files or here-string files written in **BeforeAll** / test setup; clean up in **AfterAll** where appropriate.

### Modules to test

| Module | Test? |
|--------|-------|
| **Provisioning CSV contract** (`Import-ProvisioningCsv`) | **Yes** — primary **Pester** suite for Task 3 |
| **BulkIdentityManagement** manifest smoke | Optional: export list includes **`Import-ProvisioningCsv`** after implementation |
| Private CSV helpers | **No** direct tests; covered via public command |

### Recommended test scenarios (non-exhaustive)

- Valid minimal three-column CSV (UTF-8 and UTF-8 with BOM).
- Missing required header; duplicate **Department** header; wrong-case **firstname** header.
- Required cell empty on a data row (expect throw + line number in message).
- Optional column in header with blank cell (property absent on row).
- Quoted field containing a comma.
- All-whitespace data row skipped; file with only skipped rows fails.
- Unknown column ignored (value not on row object).
- Invalid UTF-8 bytes fail.
- Malformed CSV (e.g. unclosed quote) fails.
- **`Import-ProvisioningCsv`** throws; pipeline empty on failure (**Should -Throw** / no output assertions).

### Prior art

- Task 1 **Pester** tests: manifest validation, module import hygiene, no Graph in root **psm1**—follow same **pwsh** + **Invoke-Pester** patterns and descriptive **It** blocks.
- CI will eventually run full **Pester** tree (Task 14); Task 3 adds a dedicated CSV contract test file scoped to this feature.

### Manual verification (implementation plan)

- Run **`Import-ProvisioningCsv`** against a tiny good CSV and a bad CSV in **pwsh** after tests pass.

## Out of Scope

- **Name mapping**, **MailNickname** normalization, **Identity derivation**, **UPN** collision handling (**Task 4–5**).
- **IT department rule** predicate (**Task 6**).
- **Graph gateway**, fake/real gateway, **Authentication session**, **Microsoft Graph** calls (**Tasks 7–10**).
- **Row outcome** reporting, aggregate report, output hygiene (**Task 11**).
- **Apply** orchestrator, dry run vs mutating paths, entry script (**Tasks 12–13**).
- Default CI workflow completion (**Task 14**), manual tenant workflow (**Task 15**), sample CSV and runbook (**Task 16**), lab checklist (**Task 17**).
- Semicolon/tab delimiter auto-detection; non-UTF-8 encodings; case-insensitive header aliases.
- Per-row **usage location** CSV column (**reserved for later** in **CONTEXT**).
- Committing real tenant data, production CSVs with real identifiers, or secrets in test fixtures.

## Further Notes

- **Normative alignment:** If this PRD disagrees with **CONTEXT.md**, **CONTEXT** wins.
- **Task lock:** Implement **Task 3** only; do not start **Task 4** or later in the same delivery unless explicitly expanded.
- **Implementation handoff:** Create or update a Task 3 plan/checklist when implementation begins; update parent **Implementation Plan** checkboxes only after Task 3 acceptance criteria are met.
- **Module naming:** **BulkIdentityManagement** is the v1 module name per **CONTEXT** resolved notes.
- **Checkpoint:** After Task 3, **Invoke-Pester** for CSV tests should pass without installing or authenticating **Microsoft Graph** for those tests (dot-source or selective import patterns acceptable if full module import would pull **RequiredModules** unnecessarily in CI—prefer a pattern consistent with offline deterministic gates).
