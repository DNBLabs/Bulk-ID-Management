# Implementation plan: Task 3 — Provisioning CSV contract module

**Spec:** [PRD-Task-3-Provisioning-Csv.md](PRD-Task-3-Provisioning-Csv.md). **Normative glossary:** [CONTEXT.md](../../../CONTEXT.md). **Parent ordering:** [IMPLEMENTATION-PLAN.md](../../IMPLEMENTATION-PLAN.md) (Task 3 only). **Tracker:** [DNBLabs/Bulk-ID-Management#2](https://github.com/DNBLabs/Bulk-ID-Management/issues/2).

**Scope lock:** This plan decomposes **Implementation Plan Task 3** only. It does **not** include **Name mapping** (Task 4), **Identity derivation** (Task 5), **IT department rule** (Task 6), **Graph gateway** or auth (Tasks 7–10), orchestration/reporting (Tasks 11–13), entry script (Task 13), CI workflow completion (Task 14), sample CSV/runbook (Tasks 16–17), or any **Microsoft Graph** calls.

**Repo reality (planning snapshot):** **BulkIdentityManagement** exists with empty **FunctionsToExport**. No **Public/** or **Private/** folders yet. Task 1 **Pester** tests import **`.psm1`** directly to avoid manifest **RequiredModules** side effects where possible—Task 3 tests should follow that pattern for CSV tests (dot-source or **`.psm1`** import), not **`Connect-MgGraph`**.

---

## Overview

Deliver **`Import-ProvisioningCsv -Path`**: a fail-closed, testable **Provisioning CSV contract** that reads UTF-8 (optional BOM), validates headers before data iteration, materializes **provisioning row** objects (core columns + header-gated optionals, trimmed values, **SourceLineNumber**), and throws terminating errors with physical file line numbers. Wire the command into **BulkIdentityManagement** exports and add a dedicated **Pester** suite. Leave the system ready for Tasks 4–6 to consume row objects without re-parsing CSV.

---

## Architecture decisions (frozen for this slice)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Public API** | **`Import-ProvisioningCsv -Path`** only | Single deep module entry per PRD / **CONTEXT** |
| **Failure mode** | Terminating **throw**; no pipeline rows on failure | Fail-closed before **apply** |
| **Row type** | **PSCustomObject** per row | Idiomatic PowerShell; no separate class module in v1 |
| **Optional properties** | Present on object only when header exists and cell non-empty after trim | **CONTEXT** pass-through optionals |
| **Line numbers** | **1-based physical file line** for errors and **SourceLineNumber** | Excel/editor alignment |
| **Delimiter** | Comma only; no `;` / tab sniffing | **CONTEXT** |
| **Encoding** | UTF-8 only; BOM allowed; invalid sequences fail | **CONTEXT** |
| **Unknown columns** | Ignored (not on row object) | Operator helper columns |
| **Layout** | **`Public/`** + **`Private/`** under **BulkIdentityManagement**; root **`.psm1`** dot-sources scripts | First real feature layout; keeps root thin |
| **Graph isolation** | No **Microsoft.Graph** import/call in CSV scripts or CSV **Pester** | Offline deterministic CI |
| **Parsing strategy** | **Line-aware logical record parser** (not whole-file **`Import-Csv`** alone) | Whole-file import does not reliably map **SourceLineNumber** for RFC multiline quoted records; parser must yield **start physical line** per logical row |
| **Parser implementation** | Prefer a small, test-backed record parser (e.g. **.NET** field parser or vetted line/state machine)—document choice in PR if non-obvious | Must support quoted commas; avoid silent mis-parse |
| **Test import** | **Pester** **BeforeAll** dot-sources **Public** + **Private** scripts (or imports **`.psm1`** after dot-sourcing privates)—**not** full manifest import that requires Graph auth | Matches PRD checkpoint; Task 1 precedent |

**Canonical header names (case-sensitive after trim):**

- **Required:** `FirstName`, `LastName`, `Department`
- **Optional:** `MailNickname`, `UserPrincipalName`, `GivenName`, `Surname`, `DisplayName`

---

## Dependency graph

```
Sub-task A: Public/Private layout + constants + dot-source wiring
    │
    ├── Sub-task B: UTF-8 line read (BOM + invalid bytes)
    │       │
    │       └── Sub-task C: Logical CSV record parser (RFC quotes, start line #)
    │               │
    │               ├── Sub-task D: Header validation (required, duplicate, map columns)
    │               │       │
    │               │       └── Sub-task E: Row materialization (skip empty, required cells, optionals)
    │               │               │
    │               │               └── Sub-task F: Import-ProvisioningCsv orchestration
    │               │                       │
    │               │                       └── Sub-task G: Manifest + module export wiring
    │               │                               │
    │               │                               ├── Sub-task H: Pester — success / contract cases
    │               │                               │
    │               │                               └── Sub-task I: Pester — failure / edge cases
    │               │                                       │
    │               │                                       └── Sub-task J: Closure + parent plan checkboxes
```

**Implementation order:** **A → B → C → D → E → F → G → H → I → J** (strict). **C** is the main technical risk—complete and unit-test via **`Import-ProvisioningCsv`** scenarios in **H/I** rather than testing private parser names directly.

---

## Task list

### Phase 1 — Module layout and I/O foundation

## Sub-task A: Public/Private layout, constants, and dot-source wiring

**Description:** Create **`src/Modules/BulkIdentityManagement/Public/`** and **`Private/`** folders. Add a private constants script (required/optional header name sets). Update **`BulkIdentityManagement.psm1`** to dot-source **`Private/*.ps1`** then **`Public/*.ps1`** (order: dependencies first). No public exports until **Sub-task G**.

**Acceptance criteria:**
- [x] **Public/** and **Private/** exist under **BulkIdentityManagement**. — Added `Public/` (with `.gitkeep`) and `Private/` with `ProvisioningCsv.Constants.ps1`.
- [x] Canonical required/optional column names live in one private constants location. — `$RequiredProvisioningCsvHeaderNames` and `$OptionalProvisioningCsvHeaderNames` in constants script.
- [x] Root **`.psm1`** dot-sources child scripts; still no Graph calls at import time. — Private scripts dot-sourced before Public; no Graph references in CSV layout files.

**Verification:**
- [x] Manual: **`Import-Module`** the **`.psm1`** path in **pwsh** succeeds without error. — Covered by Pester import test in `Task3.SubTaskA.ModuleLayout.Tests.ps1`.
- [x] Manual: No **`Connect-MgGraph`** / **`Import-Module Microsoft.Graph`** in new CSV scripts. — Pester scans **psm1**, **Private**, and **Public** scripts.
- [x] Security: dot-source paths resolved and confined under module root; no high-risk execution/network patterns in layout scripts (**`Task3.SubTaskA.Security.Tests.ps1`**).

**Dependencies:** None (Task 1 foundation)

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1`
- `src/Modules/BulkIdentityManagement/Private/ProvisioningCsv.Constants.ps1` (example name)

**Estimated scope:** XS

---

## Sub-task B: UTF-8 file read with BOM and invalid-byte detection

**Description:** Implement a private helper that reads the file at **`-Path`**, accepts UTF-8 with optional BOM, rejects invalid UTF-8 byte sequences, and returns content suitable for line/record parsing (e.g. array of physical lines or a single string plus line breaks). Throw clear encoding errors (terminating).

**Acceptance criteria:**
- [x] Valid UTF-8 without BOM reads successfully. — `Read-ProvisioningCsvUtf8` returns physical lines via `Task3.SubTaskB.Utf8Read.Tests.ps1`.
- [x] UTF-8 with BOM reads successfully (BOM not part of first header cell). — BOM stripped before decode; first line has no U+FEFF.
- [x] Invalid UTF-8 bytes cause terminating failure with an encoding-oriented message. — Strict `UTF8Encoding` throws wrapped `InvalidOperationException` citing UTF-8.

**Verification:**
- [x] Covered by **Sub-task H/I** Pester fixtures (binary/byte patterns or known-bad files in **TestDrive**). — Sub-task B tests use **TestDrive** fixtures; H/I may extend coverage later.
- [x] Security: **LiteralPath** leaf check, post-resolve leaf re-check, 10 MB max file size, encoding errors without inner exception leakage (**`Task3.SubTaskB.Security.Tests.ps1`**).

**Dependencies:** Sub-task A

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Private/Read-ProvisioningCsvUtf8.ps1` (example name)

**Estimated scope:** XS

---

## Sub-task C: Logical CSV record parser (comma, RFC quoting, start line)

**Description:** Implement a private parser that, given UTF-8 text/lines, yields logical CSV **records** each with **start physical line number** and **field values** (strings). Enforce comma delimiter only. Support quoted fields, commas inside quotes, and escaped quotes. Malformed records (e.g. unclosed quote) throw with an actionable parse message referencing **start line** where possible.

**Acceptance criteria:**
- [ ] Parses minimal unquoted rows correctly.
- [ ] Parses a quoted field containing a comma (e.g. `"O'Brien, Jr"`).
- [ ] Unclosed/malformed quoting fails the import (terminating).
- [ ] Each record exposes **start line number** (1-based physical line of record start).

**Verification:**
- [ ] **Sub-task I** includes quoted-field and malformed-parse cases via **`Import-ProvisioningCsv`**.
- [ ] Optional: one focused **It** with inline CSV text if it reduces flake vs file fixtures.

**Dependencies:** Sub-task B

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Private/Get-ProvisioningCsvRecord.ps1` (example name)

**Estimated scope:** S

---

### Phase 2 — Validation and materialization

## Sub-task D: Header validation and column index map

**Description:** Private logic: first logical record is the header. Trim header cells; detect duplicate canonical names after trim; verify all **required** headers present with **case-sensitive** match; build a map of canonical column → field index; **ignore** unknown header names (no error). Header problems throw before processing data records (reference header line **1** or “header row”).

**Acceptance criteria:**
- [ ] Missing **LastName** (or any required) header fails before data rows processed.
- [ ] Duplicate **Department** header fails.
- [ ] `firstname` wrong case fails (not treated as **FirstName**).
- [ ] ` EmployeeId` unknown column does not appear in column map.
- [ ] Header ` Department` (trimmed) matches **Department**.

**Verification:**
- [ ] **Sub-task I** header-focused **Pester** cases.

**Dependencies:** Sub-task C

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Private/Test-ProvisioningCsvHeader.ps1` (example name)

**Estimated scope:** XS

---

## Sub-task E: Provisioning row materialization

**Description:** Private logic: for each subsequent logical record, determine if all fields are empty/whitespace after trim → **skip**; else validate **required** fields non-empty after trim or throw with **physical line number**; build **PSCustomObject** with **SourceLineNumber**, trimmed **FirstName**/**LastName**/**Department**, and optional properties only when header existed and cell non-empty after trim. After iteration, if zero materialized rows → throw (“no provisioning rows”).

**Acceptance criteria:**
- [ ] Minimal three-column row materializes three core properties + **SourceLineNumber**.
- [ ] All-whitespace data row skipped.
- [ ] Header-only file (or only skipped rows) fails with no provisioning rows.
- [ ] Optional header + blank cell → optional property absent on object.
- [ ] Optional header + value → trimmed property present.

**Verification:**
- [ ] **Sub-task H/I** row-shape **Pester** cases.

**Dependencies:** Sub-task D

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Private/New-ProvisioningRow.ps1` (example name)

**Estimated scope:** S

---

### Phase 3 — Public command and exports

## Sub-task F: `Import-ProvisioningCsv` orchestration

**Description:** Public function **`Import-ProvisioningCsv`** with mandatory **`-Path`**. Orchestrate validation order: read UTF-8 → parse records → validate header → materialize rows → output to pipeline. Any failure: terminating throw, **no** pipeline output. Use **`[CmdletBinding()]`** and comment-based help referencing **CONTEXT** / **Provisioning CSV format**.

**Acceptance criteria:**
- [ ] Successful import writes rows to pipeline in file order.
- [ ] Any validation failure throws; **no** objects emitted.
- [ ] Missing file path handled with standard parameter/file error before contract validation (acceptable).

**Verification:**
- [ ] **Sub-task H** end-to-end **Pester** on **`Import-ProvisioningCsv`**.
- [ ] Manual: **`Import-ProvisioningCsv -Path`** on a tiny good CSV and a bad CSV in **pwsh**.

**Dependencies:** Sub-task E

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Public/Import-ProvisioningCsv.ps1`

**Estimated scope:** S

---

## Sub-task G: Manifest and `Export-ModuleMember` wiring

**Description:** Export **`Import-ProvisioningCsv`** via **`Export-ModuleMember`** in **`.psm1`** (or manifest-aligned pattern). Set **`FunctionsToExport = @('Import-ProvisioningCsv')`** in **`BulkIdentityManagement.psd1`**. Confirm **`.psm1`** still does not call Graph on import.

**Acceptance criteria:**
- [ ] **`FunctionsToExport`** lists **`Import-ProvisioningCsv`** only (for Task 3).
- [ ] **`Import-Module`** manifest path exposes the command.
- [ ] No new Graph usage in module root or CSV scripts.

**Verification:**
- [ ] **Pester:** imported module reports exported function **`Import-ProvisioningCsv`** (may use manifest import; Graph module may load but must not connect—acceptable if CI already installs pin).
- [ ] **`Invoke-ScriptAnalyzer`** clean on new **`.ps1`** files (run locally; full CI gate is Task 14).

**Dependencies:** Sub-task F

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1`
- `src/Modules/BulkIdentityManagement/BulkIdentityManagement.psd1`

**Estimated scope:** XS

---

### Phase 4 — Automated tests

## Sub-task H: Pester — success and contract scenarios

**Description:** Add **`tests/Task3.ProvisioningCsv.Success.Tests.ps1`** (or equivalent). **BeforeAll:** resolve repo root, dot-source module scripts (avoid Graph auth). Use **TestDrive** or **`tests/fixtures/csv/`** for UTF-8 fixtures. Cover: minimal good CSV; UTF-8 BOM; optional columns present/absent; quoted comma field; unknown column ignored; **SourceLineNumber** values; trimmed values; multiple rows in order.

**Acceptance criteria:**
- [ ] **`Invoke-Pester`** on this file passes in **pwsh** without tenant credentials.
- [ ] Tests assert observable row properties, not private function names.

**Verification:**
- [ ] `pwsh -NoProfile -Command "Invoke-Pester -Path 'tests/Task3.ProvisioningCsv.Success.Tests.ps1' -CI"`

**Dependencies:** Sub-task G

**Files likely touched:**
- `tests/Task3.ProvisioningCsv.Success.Tests.ps1`
- `tests/fixtures/csv/*.csv` (optional committed fixtures)

**Estimated scope:** S

---

## Sub-task I: Pester — failure and edge scenarios

**Description:** Add **`tests/Task3.ProvisioningCsv.Failure.Tests.ps1`**. Cover: missing header; duplicate header; wrong-case header; empty required cell (message includes line number); invalid UTF-8; malformed parse; semicolon-separated misfile (fails headers); header-only / all-blank rows; throw leaves pipeline empty (**`Should -Throw`** + no output).

**Acceptance criteria:**
- [ ] All failure tests pass in **pwsh** without Graph.
- [ ] Row-level errors assert line number appears in exception message where stable.

**Verification:**
- [ ] `pwsh -NoProfile -Command "Invoke-Pester -Path 'tests/Task3.ProvisioningCsv.Failure.Tests.ps1' -CI"`

**Dependencies:** Sub-task G (may run parallel with **H** after **G**)

**Files likely touched:**
- `tests/Task3.ProvisioningCsv.Failure.Tests.ps1`

**Estimated scope:** S

---

### Phase 5 — Closure

## Sub-task J: Task 3 closure and parent plan update

**Description:** Run full Task 3 **Pester** subset + **PSScriptAnalyzer** on new scripts. Manual smoke (good/bad CSV). Update **`docs/IMPLEMENTATION-PLAN.md`** Task 3 acceptance/verification checkboxes. Add **`docs/tasks/task-3/`** completion notes if useful. Do **not** check Task 4+ boxes.

**Acceptance criteria:**
- [ ] Parent plan Task 3 acceptance criteria satisfied (headers before rows, UTF-8/BOM, clear errors, tests pass).
- [ ] No Task 4+ code or tests introduced.
- [ ] Issue **#2** can move to review/close per team process.

**Verification:**
- [ ] `Invoke-Pester` Task 3 tests green.
- [ ] Manual: good + bad CSV per implementation plan.
- [ ] Quick review: CSV error messages human-readable.

**Dependencies:** Sub-tasks H, I

**Files likely touched:**
- `docs/IMPLEMENTATION-PLAN.md`
- `docs/tasks/task-3/PLAN-Task-3-Provisioning-Csv.md` (checkboxes)

**Estimated scope:** XS

---

## Checkpoints

### Checkpoint: After Sub-task C
- [ ] UTF-8 read works for BOM and non-BOM fixtures.
- [ ] Record parser returns expected field count on a quoted-comma fixture.
- [ ] Malformed CSV throws before any row materialization.
- [ ] Proceed to header/row logic only when parser is stable.

### Checkpoint: After Sub-task G
- [ ] **`Import-ProvisioningCsv`** callable from imported module.
- [ ] Good minimal CSV returns ≥1 row with expected properties.
- [ ] Bad header CSV throws.
- [ ] No Graph calls in CSV code paths.

### Checkpoint: Task 3 complete (after Sub-task J)
- [ ] **`Invoke-Pester`** passes for **H** + **I** without live tenant.
- [ ] **IMPLEMENTATION-PLAN** Task 3 boxes updated.
- [ ] Ready for **Task 4** (depends on stable **provisioning row** shape)—do **not** start Task 4 in this delivery.

---

## Parallelization

| Safe parallel | Must be sequential |
|---------------|-------------------|
| **H** and **I** after **G** | **A→B→C→D→E→F→G** |
| Fixture authoring while building **C–E** (same agent/session caution) | Parser before header/row logic |

---

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Import-Csv** used for whole file → wrong **SourceLineNumber** | High | **Sub-task C** line-aware parser; test multiline quoted records in **I** if supported |
| **RequiredModules** slows/blocks tests | Medium | Dot-source **Private**/**Public** in **Pester** **BeforeAll**; manifest smoke only in **G** |
| **PSScriptAnalyzer** warnings on new scripts | Low | Run analyzer locally in **J**; follow Task 1 comment/help patterns |
| Semicolon CSV looks “almost valid” | Low | **I** includes mis-delimiter fixture; expect header missing failure |
| Over-testing private helpers | Low | PRD: test **`Import-ProvisioningCsv`** behavior only |

---

## Open questions

- **None blocking** — contract is frozen in **CONTEXT** and [PRD-Task-3-Provisioning-Csv.md](PRD-Task-3-Provisioning-Csv.md). If **Sub-task C** chooses **TextFieldParser** vs custom FSM, note the choice in the implementing PR description (ADR only if surprising and hard to reverse).

---

## Human review gate

Maintainer should confirm this plan (or request edits) before large implementation spend on **Sub-task C** parser work.

**After approval:** Implement **A → J** in order; update this plan’s checkboxes as sub-tasks complete.
