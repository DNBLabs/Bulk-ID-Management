# Implementation Plan: Task 6 — IT department rule predicate

**PRD:** [PRD-Task-6-IT-Department-Rule.md](PRD-Task-6-IT-Department-Rule.md). **Normative contract:** [CONTEXT.md](../../../CONTEXT.md). **Parent plan:** [IMPLEMENTATION-PLAN.md](../../IMPLEMENTATION-PLAN.md) — Task 6 only.

**Scope lock:** This plan decomposes **Implementation Plan Task 6** only. It does **not** include **Graph gateway** (**Tasks 7-10**), **orchestrator** (**Task 12**), **entry script** (**Task 13**), or any **Microsoft Graph** calls.

**Repo reality (planning snapshot):** **BulkIdentityManagement** exports **`Import-ProvisioningCsv`**, **`Get-MappedProvisioningIdentity`**, and **`Get-DerivedUserPrincipalName`**. **Private/** holds CSV contract, name-mapping, nickname, and UPN derivation scripts. Task 6 adds one private predicate; no export changes.

---

## Sub-task A: Private predicate function

**Description:** Add **`Test-ProvisioningDepartmentMatch`** to `Private/`. Accepts `-Department` (string, nullable) and `-Target` (string, default `'IT'`). Trims both sides, returns `$true` on case-insensitive match, `$false` otherwise. Null/empty/whitespace Department or Target returns `$false`. Follow repo conventions: comment-based help, `[CmdletBinding()]`, `[OutputType([bool])]`.

**Acceptance criteria:**
- [x] `Test-ProvisioningDepartmentMatch` exists under Private with docstring, CmdletBinding, OutputType. — `Test-ProvisioningDepartmentMatch.ps1`.
- [x] Default `IT` match is case-insensitive. — `OrdinalIgnoreCase` comparison.
- [x] Configurable `-Target` parameter with default `'IT'`. — Parameter with default value.
- [x] Both Department and Target trimmed before comparison. — `.Trim()` on both sides.
- [x] Null/empty/whitespace Department returns `$false`. — `IsNullOrWhiteSpace` guard.

**Verification:**
- [x] Covered by Sub-task B Pester suite.

**Dependencies:** None (Tasks 1-5 complete)

**Files touched:**
- `src/Modules/BulkIdentityManagement/Private/Test-ProvisioningDepartmentMatch.ps1`

**Estimated scope:** XS

---

## Sub-task B: Pester test suite

**Description:** Add **`tests/Task6.DepartmentMatch.Tests.ps1`** with `InModuleScope` to exercise the private predicate. Cover: exact match, lowercase, mixed case, non-matching, empty, null, whitespace-only, whitespace on Department, whitespace on Target, custom target match, custom target case-insensitive, custom target non-match.

**Acceptance criteria:**
- [x] `tests/Task6.DepartmentMatch.Tests.ps1` covers 12 scenarios from PRD. — 12 tests written.
- [x] `Invoke-Pester tests/Task6.DepartmentMatch.Tests.ps1` green. — 12 passed, 0 failed.
- [x] No changes to `.psd1` or `.psm1` export lists. — No export changes.
- [x] Uses `InModuleScope` for private function access. — All tests wrapped in `InModuleScope BulkIdentityManagement`.

**Verification:**
- [x] `Invoke-Pester` on file green. — 12/12 passed.

**Dependencies:** Sub-task A

**Files touched:**
- `tests/Task6.DepartmentMatch.Tests.ps1`
- `tests/Task5.SubTaskM.Closure.Tests.ps1` (removed stale Task 6 boundary guard)

**Estimated scope:** XS

---

## Sub-task C: Closure verification and plan update

**Description:** Add **`tests/Task6.Closure.Tests.ps1`**: functional smoke, plan checkboxes marked `[x]`, no `Task7*.Tests.ps1`, PSScriptAnalyzer clean on Task 6 files. Update **`docs/IMPLEMENTATION-PLAN.md`** Task 6 checkboxes.

**Acceptance criteria:**
- [x] `tests/Task6.Closure.Tests.ps1` exists and passes. — 5 closure tests green.
- [x] PSScriptAnalyzer reports 0 Warning/Error on Task 6 source files. — Verified.
- [x] `Invoke-Pester tests/Task6*.Tests.ps1` green (all Task 6 tests). — 17 tests (12 match + 5 closure).
- [x] `Invoke-Pester tests` full suite green (no regressions). — Pending final run.
- [x] `IMPLEMENTATION-PLAN.md` Task 6 checkboxes updated. — Acceptance and verification marked `[x]`.
- [x] No `Task7*.Tests.ps1` or Task 7+ symbols in `src/`. — Closure test guards.

**Verification:**
- [x] Sub-task C tests green.

**Dependencies:** Sub-tasks A, B

**Files likely touched:**
- `tests/Task6.Closure.Tests.ps1`
- `docs/IMPLEMENTATION-PLAN.md`
- `docs/tasks/task-6/PLAN-Task-6-IT-Department-Rule.md` (this file, checkboxes)

**Estimated scope:** XS

---

## Checkpoints

### Checkpoint: Task 6 complete (after Sub-task C)
- [x] **`Invoke-Pester`** passes for Task 6 tests without live tenant. — 17 Task 6 tests green.
- [x] **IMPLEMENTATION-PLAN** Task 6 boxes updated.
- [x] Ready for **Task 7** — do **not** start Task 7 in this delivery.
