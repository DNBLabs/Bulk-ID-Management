# Implementation plan: Task 4 — Name mapping and MailNickname normalization

**Spec:** [PRD-Task-4-Name-Mapping-MailNickname.md](PRD-Task-4-Name-Mapping-MailNickname.md). **Normative glossary:** [CONTEXT.md](../../../CONTEXT.md). **Parent ordering:** [IMPLEMENTATION-PLAN.md](../../IMPLEMENTATION-PLAN.md) (Task 4 only). **Tracker:** [DNBLabs/Bulk-ID-Management#3](https://github.com/DNBLabs/Bulk-ID-Management/issues/3).

**Scope lock:** This plan decomposes **Implementation Plan Task 4** only. It does **not** include **UserPrincipalName** composition or collision suffix (**Task 5**), **IT department rule** (**Task 6**), **Graph gateway** or auth (**Tasks 7–10**), orchestration/reporting (**Tasks 11–13**), entry script (**Task 13**), CI workflow completion (**Task 14**), sample CSV/runbook (**Tasks 16–17**), or any **Microsoft Graph** calls.

**Repo reality (closure snapshot):** **BulkIdentityManagement** exports **`Import-ProvisioningCsv`** and **`Get-MappedProvisioningIdentity`**. **Private/** holds name-mapping and nickname scripts; **Public/** holds the mapped-identity cmdlet. Task 4 **Pester** imports **`.psm1`** without **`Connect-MgGraph`** (same pattern as Task 3).

---

## Overview

Deliver **`Get-MappedProvisioningIdentity -ProvisioningRow`**: a fail-closed, pure **mapped provisioning identity** boundary that applies **Name mapping** (defaults, optional CSV overrides, diacritics preserved on display fields) and **MailNickname** derivation/normalization per **CONTEXT**, returning a new **PSCustomObject** without mutating the input **provisioning row**. Wire the command into **BulkIdentityManagement** exports and add dedicated **Pester** suites. Leave **UserPrincipalName** on the row for **Task 5**.

---

## Architecture decisions (frozen for this slice)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Public API** | **`Get-MappedProvisioningIdentity -ProvisioningRow`** only | Single deep module entry per PRD / **CONTEXT** |
| **Failure mode (invalid nickname)** | Terminating **`System.InvalidOperationException`** with physical line in message | Matches Task 3; orchestrator maps to **row outcome** **failed** later |
| **Output type** | **PSCustomObject** (**mapped provisioning identity**) | Idiomatic PowerShell; aligns with **provisioning row** |
| **Property names** | PascalCase: **GivenName**, **Surname**, **DisplayName**, **MailNickname**, **SourceLineNumber** | Consistent with row objects |
| **Input mutation** | None | **Department**, **UserPrincipalName**, **FirstName** remain on row |
| **DisplayName default** | **FirstName** + space + **LastName** (trim/collapse each part)—**not** mapped **GivenName** | **CONTEXT** / PRD (legal display vs preferred **GivenName**) |
| **Nickname default base** | Mapped **GivenName** + **`.`** + mapped **Surname** | Aligns alias with Entra given/surname after overrides |
| **CSV MailNickname** | Same normalization pipeline as derived (not pass-through) | **CONTEXT** |
| **Nickname charset** | **`[a-z0-9.-]`** after lowercase, Form D accent strip, **ß→ss**, space removal, collapse/trim | Grill session / **CONTEXT** |
| **Name field diacritics** | Preserved on **GivenName** / **Surname** / **DisplayName** | Human-facing Entra attributes |
| **Layout** | New **Private/** scripts + **Public/Get-MappedProvisioningIdentity.ps1**; dot-sourced by existing **`.psm1`** | Matches Task 3 layout |
| **Graph isolation** | No **Microsoft.Graph** import/call in Task 4 scripts or Task 4 **Pester** | Offline deterministic CI |
| **Test import** | **Pester** **BeforeAll** dot-sources **Private** then **Public** (or imports **`.psm1`** after privates loaded)—manifest smoke asserts **FunctionsToExport** | Task 3 precedent |

**Reference examples (derived nickname, no CSV MailNickname):**

| FirstName | LastName | GivenName (row) | GivenName (out) | DisplayName (out) | MailNickname |
|-----------|----------|-----------------|-----------------|-------------------|--------------|
| Ada | Lovelace | — | Ada | Ada Lovelace | ada.lovelace |
| José | García | — | José | José García | jose.garcia |
| Mary Jane | Watson | — | Mary Jane | Mary Jane Watson | maryjane.watson |
| Robert | Smith | Bob | Bob | Robert Smith | bob.smith |
| Anne | O'Brien | — | Anne | Anne O'Brien | anne.obrien |
| Jean-Luc | Picard | — | Jean-Luc | Jean-Luc Picard | jean-luc.picard |
| Björn | Weiß | — | Björn | Björn Weiß | bjorn.weiss |

---

## Dependency graph

```
Sub-task A: Private trim/collapse helper
    │
    ├── Sub-task B: Private name mapping from provisioning row
    │       │
    │       └── Sub-task C: Private MailNickname normalization pipeline
    │               │
    │               └── Sub-task D: Public Get-MappedProvisioningIdentity orchestration
    │                       │
    │                       └── Sub-task E: Manifest + Export-ModuleMember wiring
    │                               │
    │                               ├── Sub-task F: Pester — name mapping (defaults, overrides, display rules, diacritics)
    │                               │
    │                               ├── Sub-task G: Pester — MailNickname (derive, CSV override, edge charset)
    │                               │
    │                               ├── Sub-task H: Pester — failures + row immutability
    │                               │
    │                               └── Sub-task I: Pester — export smoke + optional Import→Map integration
    │                                       │
    │                                       └── Sub-task J: Closure + parent plan checkboxes
```

**Implementation order:** **A → B → C → D → E → F → G → H → I → J** (strict). **C** is the main technical risk (Unicode normalization)—cover with table-driven cases in **G** via the public cmdlet, not private function names.

---

## Task list

### Phase 1 — Private foundations

## Sub-task A: Trim and collapse whitespace helper

**Description:** Add a private function (e.g. **`Format-ProvisioningIdentityNamePart`**) that trims leading/trailing whitespace and collapses internal runs of whitespace to a single space. Used by name mapping and nickname base building. No Graph; no row awareness.

**Acceptance criteria:**
- [x] Leading/trailing whitespace removed. — `Format-ProvisioningIdentityNamePart.ps1`.
- [x] Internal runs of spaces/tabs collapsed to one ASCII space. — Regex collapse in same helper.
- [x] Empty or whitespace-only input returns empty string (callers validate required row fields separately). — Used by name mapping; row required-field checks in boundary helper.

**Verification:**
- [x] Exercised indirectly via **Sub-task F** once **D** exists; optional minimal direct tests only if needed for debugging (prefer public surface). — `Task4.NameMapping.Tests.ps1` trim/collapse cases.

**Dependencies:** None (Task 3 complete)

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Private/Format-ProvisioningIdentityNamePart.ps1` (example name)

**Estimated scope:** XS

---

## Sub-task B: Private name mapping from provisioning row

**Description:** Implement private **`Get-ProvisioningNameMappingFromRow`** (example name) that accepts a **provisioning row** and returns a small hashtable or ordered dict with **GivenName**, **Surname**, **DisplayName** per **CONTEXT**: defaults from **FirstName**/**LastName**; overrides when **GivenName** / **Surname** / **DisplayName** properties exist on the row; **DisplayName** default from **FirstName** + space + **LastName** (not from mapped **GivenName**); diacritics preserved; trim/collapse on all outputs.

**Acceptance criteria:**
- [x] Default mapping: **GivenName** ← **FirstName**, **Surname** ← **LastName**, **DisplayName** ← formatted **FirstName** + **LastName**. — `Get-ProvisioningNameMappingFromRow.ps1`.
- [x] **GivenName** / **Surname** / **DisplayName** row overrides replace corresponding field when property present. — Override branches in same helper.
- [x] **Robert** + row **GivenName** `Bob` → **GivenName** `Bob`, **DisplayName** `Robert Smith` (trimmed/collapsed). — `Task4.NameMapping.Tests.ps1` and Sub-task J smoke.
- [x] Diacritics unchanged on mapped name fields (e.g. **José**, **García**). — `Task4.NameMapping.Tests.ps1` diacritic case.

**Verification:**
- [x] Covered by **Sub-task F** via **`Get-MappedProvisioningIdentity`**. — `Task4.NameMapping.Tests.ps1`.

**Dependencies:** Sub-task A

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Private/Get-ProvisioningNameMappingFromRow.ps1` (example name)

**Estimated scope:** S

---

## Sub-task C: Private MailNickname normalization pipeline

**Description:** Implement private **`Get-NormalizedProvisioningMailNickname`** (example name) with two entry paths: (1) **base string** already dot-joined from mapped names; (2) **CSV override** string. Apply pipeline: lowercase; **ß→ss** before or after Form D (document order in code comment only if non-obvious); Form D + strip non-spacing marks; remove all spaces; filter to **`[a-z0-9.-]`**; collapse repeated **`.`** and **`-`**; trim leading/trailing **`.`** and **`-`**; validate non-empty and at least one **`a-z`**. On validation failure, throw **`System.InvalidOperationException`** including **SourceLineNumber** parameter passed in from caller.

**Acceptance criteria:**
- [x] Derived base: mapped **GivenName** + **`.`** + mapped **Surname** (parts formatted with Sub-task A) before pipeline. — `Get-NormalizedProvisioningMailNickname.ps1` derive path.
- [x] CSV **MailNickname** on row uses same pipeline (e.g. `ADA.LOVELACE` → `ada.lovelace`). — Override path in same function.
- [x] PRD reference table cases pass (José/García, Mary Jane, Bob/Robert, O'Brien, Jean-Luc, Björn/Weiß). — `Task4.MailNickname.Tests.ps1` and name-mapping tests.
- [x] Invalid values (`!!!`, `---`, punctuation-only) throw with line number in message. — `Task4.MappingFailures.Tests.ps1`.

**Verification:**
- [x] Covered by **Sub-task G** and **H** via public cmdlet. — `Task4.MailNickname.Tests.ps1`, `Task4.MappingFailures.Tests.ps1`.

**Dependencies:** Sub-task A (formatting parts); **B** provides mapped names for derive path

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Private/Get-NormalizedProvisioningMailNickname.ps1` (example name)

**Estimated scope:** S

---

### Phase 2 — Public orchestration and exports

## Sub-task D: Public `Get-MappedProvisioningIdentity`

**Description:** Add **`Public/Get-MappedProvisioningIdentity.ps1`**. Validate **ProvisioningRow** has **SourceLineNumber**, **FirstName**, **LastName**, **Department** (throw **`ArgumentException`** or **`InvalidOperationException`** for malformed row object—distinct message from nickname validation). Call **B** then **C** (derive vs CSV **MailNickname** branch). Return new **PSCustomObject** with **SourceLineNumber**, **GivenName**, **Surname**, **DisplayName**, **MailNickname**. Do not mutate **ProvisioningRow**.

**Acceptance criteria:**
- [x] Success returns all five properties on a new object. — `Get-MappedProvisioningIdentity.ps1`.
- [x] Input row property values unchanged after call (reference same object; compare **FirstName** / optional props). — `Task4.MappingFailures.Tests.ps1` immutability case.
- [x] Row with **MailNickname** property uses override path; row without property derives nickname. — `Task4.MailNickname.Tests.ps1`.
- [x] Invalid nickname throws **`System.InvalidOperationException`** citing physical line (e.g. `physical line 4`). — `Task4.MappingFailures.Tests.ps1` and Sub-task J smoke.

**Verification:**
- [x] **F**, **G**, **H** green in **pwsh**. — `tests/Task4*.Tests.ps1` (**34** tests including security suite).

**Dependencies:** Sub-tasks B, C

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Public/Get-MappedProvisioningIdentity.ps1`

**Estimated scope:** S

---

## Sub-task E: Manifest and module export wiring

**Description:** Add **`Get-MappedProvisioningIdentity`** to **`BulkIdentityManagement.psd1`** **FunctionsToExport**. Update **`BulkIdentityManagement.psm1`** **`Export-ModuleMember`** to include both **`Import-ProvisioningCsv`** and **`Get-MappedProvisioningIdentity`**. Ensure new scripts are dot-sourced automatically via existing **Private/** / **Public/** glob (no Graph).

**Acceptance criteria:**
- [x] **FunctionsToExport** lists both CSV import and mapped identity commands. — `BulkIdentityManagement.psd1`.
- [x] **`Export-ModuleMember`** matches manifest. — `BulkIdentityManagement.psm1`.
- [x] Importing **`.psm1`** in **pwsh** exposes both commands without Graph auth. — `Task3.SubTaskG.ModuleExport.Tests.ps1`, `Task4.SubTaskI.ModuleExport.Tests.ps1`.

**Verification:**
- [x] **Sub-task I** manifest tests pass. — `Task4.SubTaskI.ModuleExport.Tests.ps1`.
- [x] Manual: `Import-Module ./BulkIdentityManagement.psm1 -Force; Get-Command Get-MappedProvisioningIdentity` — Covered by export Pester suites and CI module-manifest job.

**Dependencies:** Sub-task D

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/BulkIdentityManagement.psd1`
- `src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1`

**Estimated scope:** XS

---

### Phase 3 — Pester (no Graph)

## Sub-task F: Pester — name mapping behavior

**Description:** Add **`tests/Task4.NameMapping.Tests.ps1`**. Build **provisioning row** **PSCustomObject** fixtures in tests (same property names as Task 3). Assert **GivenName**, **Surname**, **DisplayName** via **`Get-MappedProvisioningIdentity`** (observable outputs only). Include: minimal row; **GivenName** / **Surname** / **DisplayName** overrides; Robert/Bob display rule; diacritics preserved on name fields; trim/collapse on double spaces.

**Acceptance criteria:**
- [x] All scenarios in PRD “name mapping” section covered. — `Task4.NameMapping.Tests.ps1`.
- [x] No assertions on private function names. — Tests call `Get-MappedProvisioningIdentity` only.
- [x] **`Invoke-Pester`** passes without tenant credentials. — Green in local and CI full suite.

**Verification:**
- [x] `pwsh -NoProfile -Command "Invoke-Pester -Path 'tests/Task4.NameMapping.Tests.ps1' -CI"` — Part of `tests/Task4*.Tests.ps1`.

**Dependencies:** Sub-task E

**Files likely touched:**
- `tests/Task4.NameMapping.Tests.ps1`

**Estimated scope:** S

---

## Sub-task G: Pester — MailNickname behavior

**Description:** Add **`tests/Task4.MailNickname.Tests.ps1`**. Assert **MailNickname** on mapped object: PRD reference table, CSV override normalization, hyphen retention, apostrophe stripping, `John..Smith` collapse, multi-word first name. Use stable row **SourceLineNumber** values for failure tests delegated to **H** where appropriate.

**Acceptance criteria:**
- [x] PRD nickname table and override cases covered. — `Task4.MailNickname.Tests.ps1`.
- [x] **`Invoke-Pester`** passes without Graph. — Green in local and CI.

**Verification:**
- [x] `pwsh -NoProfile -Command "Invoke-Pester -Path 'tests/Task4.MailNickname.Tests.ps1' -CI"` — Part of `tests/Task4*.Tests.ps1`.

**Dependencies:** Sub-task E (may run parallel with **F** after **E**)

**Files likely touched:**
- `tests/Task4.MailNickname.Tests.ps1`

**Estimated scope:** S

---

## Sub-task H: Pester — failures and row immutability

**Description:** Add **`tests/Task4.MappingFailures.Tests.ps1`**. Cover: invalid **MailNickname** (throw, message contains physical line); malformed row missing required properties; **`Should -Throw`**; assert input row unchanged after failed/successful map. Optional: row missing **MailNickname** property vs empty—only property absence triggers derive (Task 3 omits property when blank).

**Acceptance criteria:**
- [x] Failure tests pass; messages cite **SourceLineNumber** where stable. — `Task4.MappingFailures.Tests.ps1`.
- [x] Immutability test compares row before/after. — Same suite.

**Verification:**
- [x] `pwsh -NoProfile -Command "Invoke-Pester -Path 'tests/Task4.MappingFailures.Tests.ps1' -CI"` — Part of `tests/Task4*.Tests.ps1`.

**Dependencies:** Sub-task E (parallel with **F**, **G** after **E**)

**Files likely touched:**
- `tests/Task4.MappingFailures.Tests.ps1`

**Estimated scope:** S

---

## Sub-task I: Pester — export smoke and Import→Map integration

**Description:** Add **`tests/Task4.SubTaskI.ModuleExport.Tests.ps1`** (or extend Task 1 manifest tests minimally): **FunctionsToExport** contains **`Get-MappedProvisioningIdentity`**. Add one integration test: small UTF-8 CSV in **TestDrive** → **`Import-ProvisioningCsv`** → **`Get-MappedProvisioningIdentity`** on first row (accented or override case). Scan new Task 4 scripts for **Microsoft.Graph** / **`Connect-MgGraph`** (mirror Task 3 Sub-task A).

**Acceptance criteria:**
- [x] Manifest export list includes new function. — `Task4.SubTaskI.ModuleExport.Tests.ps1`.
- [x] Import→Map smoke passes. — Accented CSV integration test in same file.
- [x] No Graph references in Task 4 source files. — Static scan in same file.

**Verification:**
- [x] `Invoke-Pester` on **Sub-task I** file green. — Also `Task4.Mapping.Security.Tests.ps1` for bounds.

**Dependencies:** Sub-task E

**Files likely touched:**
- `tests/Task4.SubTaskI.ModuleExport.Tests.ps1`
- `tests/Task4.SubTaskI.ImportMapIntegration.Tests.ps1` (optional split)

**Estimated scope:** XS–S

---

### Phase 4 — Closure

## Sub-task J: Task 4 closure and parent plan update

**Description:** Run full Task 4 **Pester** subset + **PSScriptAnalyzer** on new **`.ps1`** files. Manual smoke in **pwsh** (map one row object). Update **`docs/IMPLEMENTATION-PLAN.md`** Task 4 acceptance/verification checkboxes. Update this plan’s checkboxes. Do **not** check Task 5+ boxes or add UPN code.

**Acceptance criteria:**
- [x] Parent plan Task 4 acceptance criteria satisfied (**givenName**/display rules, nickname edge cases in Pester, overrides active in v1). — **IMPLEMENTATION-PLAN** Task 4 boxes updated.
- [x] No Task 5+ code or tests introduced (no **`Task5*.Tests.ps1`**, no UPN builder). — Closure test guards Task 5 scope.
- [x] Issue **#3** ready for review per team process. — Implementation complete pending maintainer review.

**Verification:**
- [x] `Invoke-Pester` Task 4 tests green. — `tests/Task4*.Tests.ps1` (**34** tests).
- [x] Manual: map row with **José**/**García** and Robert/**GivenName** Bob; confirm outputs. — `Task4.SubTaskJ.Closure.Tests.ps1` smoke scenarios.
- [x] Optional: `tests/Task4.SubTaskJ.Closure.Tests.ps1` asserting parent plan Task 4 boxes and no Task 5 files (mirror Task 3 **Sub-task J**). — Added closure suite.

**Dependencies:** Sub-tasks F, G, H, I

**Files likely touched:**
- `docs/IMPLEMENTATION-PLAN.md`
- `docs/tasks/task-4/PLAN-Task-4-Name-Mapping-MailNickname.md` (checkboxes)
- `tests/Task4.SubTaskJ.Closure.Tests.ps1` (optional)

**Estimated scope:** XS

---

## Checkpoints

### Checkpoint: After Sub-task C
- [x] Nickname pipeline returns expected values for José/García and Mary Jane fixtures in a local **pwsh** scratch call or early **G** draft. — `Task4.MailNickname.Tests.ps1`.
- [x] Invalid nickname throws with line number before public orchestration is wired. — `Task4.MappingFailures.Tests.ps1`.
- [x] Proceed to **D** only when normalization table matches **CONTEXT**. — Public cmdlet wired in Sub-task D.

### Checkpoint: After Sub-task E
- [x] **`Get-MappedProvisioningIdentity`** callable from imported **`.psm1`**. — `Task4.SubTaskI.ModuleExport.Tests.ps1`.
- [x] Minimal row maps to **ada.lovelace**-style nickname for Ada Lovelace. — `Task4.NameMapping.Tests.ps1`.
- [x] No Graph calls in new scripts. — Static scan in Sub-task I tests.

### Checkpoint: Task 4 complete (after Sub-task J)
- [x] **`Invoke-Pester`** passes for **F**–**I** (and optional **J**) without live tenant. — **34** Task 4 tests green (includes security suite).
- [x] **IMPLEMENTATION-PLAN** Task 4 boxes updated. — Parent plan Task 4 acceptance/verification marked complete.
- [x] Ready for **Task 5** (**Identity derivation** / UPN)—do **not** start Task 5 in this delivery. — No Task 5 code or tests introduced.

---

## Parallelization

| Safe parallel | Must be sequential |
|---------------|-------------------|
| **F**, **G**, **H** after **E** | **A→B→C→D→E** |
| Fixture/hashtable authoring while building **B–C** | **B** before derive path in **C**/**D** |
| **I** manifest smoke parallel with **F–H** after **E** | **C** before **D** |

---

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Unicode normalization differs on Linux CI vs Windows | Medium | Use **.NET** **`StringNormalizationForm.FormD`** explicitly; table-driven **G** tests in **pwsh** on CI OS |
| **ß** handling order vs Form D | Low | Document order in implementing PR; test **Björn**/**Weiß** in **G** |
| **RequiredModules** slows tests | Medium | Dot-source **Private**/**Public** in **BeforeAll**; full manifest import only in **I** |
| **PSScriptAnalyzer** warnings on new scripts | Low | Run analyzer in **J**; match Task 3 comment/help style |
| Accidental UPN/collision code in Task 4 | Medium | **J** closure scan for Task 5 symbols; PR scope lock |
| Testing private helpers instead of public API | Low | PRD: test **`Get-MappedProvisioningIdentity`** only |
| Unbounded CSV cell strings in mapping | Medium | **`ProvisioningIdentity.Constants.ps1`** length caps; **`Test-ProvisioningIdentityRowBoundary`**; **`Task4.Mapping.Security.Tests.ps1`** |

---

## Open questions

- **None blocking** — contract frozen in **CONTEXT** and [PRD-Task-4-Name-Mapping-MailNickname.md](PRD-Task-4-Name-Mapping-MailNickname.md). If **ß** replacement order relative to Form D surprises maintainers, note in PR body (ADR only if hard to reverse).

---

## Human review gate

Maintainer should confirm this plan (or request edits) before implementation spend.

**After approval:** Implement **A → J** in order; update this plan’s checkboxes as sub-tasks complete.
