# PRD: Task 6 — IT department rule predicate

**Normative glossary:** [CONTEXT.md](../../../CONTEXT.md). **Parent product PRD:** [PRD.md](../../PRD.md). **Implementation slice:** [IMPLEMENTATION-PLAN.md](../../IMPLEMENTATION-PLAN.md) — Task 6 only.

**Design references:** [HLD.md](../../HLD.md), [SEC.md](../../SEC.md). **Background only:** [init-project.txt](../../init-project.txt).

**Issue tracker:** Published as [DNBLabs/Bulk-ID-Management#5](https://github.com/DNBLabs/Bulk-ID-Management/issues/5) with the **`ready-for-agent`** label.

**Prerequisites:** Task 3 **`Import-ProvisioningCsv`** (**provisioning row** objects with **Department** always present).

---

## Problem Statement

The orchestrator (Task 12) needs to decide, for each **provisioning row**, whether the user qualifies for **IT membership ensure** — adding them to the pre-created **IT membership group**. The matching logic is simple (case-insensitive Department comparison), but it must be isolated in a testable predicate so that the orchestrator does not inline string comparison and so that edge cases (whitespace, casing, empty input) are covered by **Pester** in default **CI validation gates** without calling **Microsoft Graph**.

Without a dedicated predicate, the orchestrator would embed matching logic that is hard to test in isolation and easy to break during refactoring.

## Solution

Add a private function **`Test-ProvisioningDepartmentMatch`** to **BulkIdentityManagement** that accepts a **Department** string and a configurable **Target** string (default **`IT`**), trims both sides, and returns **`$true`** when they are equal under case-insensitive comparison. Null or empty **Department** returns **`$false`**. The function is not exported — it is consumed only by the orchestrator and exercised via **Pester**.

## User Stories

1. As an **identity operator**, I want rows with **Department** `IT` to automatically qualify for IT group membership, so that IT users are provisioned into the correct security group without manual intervention.
2. As an **identity operator**, I want the department match to be case-insensitive, so that CSV values like `it`, `It`, or `IT` all qualify without data cleanup.
3. As an **identity operator**, I want accidental whitespace in my target parameter (e.g. `" IT "`) to still match, so that a trailing space in configuration does not silently suppress membership.
4. As a **contributor**, I want the IT rule as a standalone private function, so that the orchestrator delegates matching rather than inlining string comparison.
5. As a **contributor**, I want the target department to be a configurable parameter (not hardcoded to `"IT"`), so that operators or future rules can match other department names without code changes.
6. As a **contributor**, I want null or empty Department to return `$false` (not throw), so that the predicate is safe to call on any row without defensive guards in the orchestrator.
7. As a **contributor**, I want the function to follow the repo's private helper conventions (docstring, `[CmdletBinding()]`, `[OutputType([bool])]`), so that code style is consistent across tasks.
8. As a **security reviewer**, I want Task 6 to perform no Apply or Graph operations, so that default CI needs no tenant credentials.
9. As a **maintainer**, I want **Pester** tests covering casing, whitespace, empty, null, non-matching, and exact-match scenarios, so that the predicate is protected by CI.
10. As a **maintainer**, I want Task 6 delivery to not start Task 7+ (Graph gateway, orchestrator, etc.), so that scope creep is prevented.

## Implementation Decisions

### Module to build

| Module / unit | Role | Public surface |
|---------------|------|----------------|
| **`Test-ProvisioningDepartmentMatch`** (private) | Deep predicate: trim both sides, case-insensitive equality | Not exported |

### Function contract

| Parameter | Required | Type | Notes |
|-----------|----------|------|-------|
| **Department** | No | `[string]` | Row's Department value. Null/empty returns `$false`. |
| **Target** | No | `[string]` | Configurable match target. Default `'IT'`. Trimmed before comparison. |

**Return:** `[bool]` — `$true` if trimmed Department equals trimmed Target (case-insensitive); `$false` otherwise.

### Behavior rules

- Both **Department** and **Target** are trimmed (leading/trailing whitespace removed) before comparison.
- Comparison is **case-insensitive** (PowerShell `-ieq` or `.Equals(..., OrdinalIgnoreCase)`).
- Null, empty, or whitespace-only **Department** returns `$false` — no throw.
- Null or whitespace-only **Target** returns `$false` — a blank target matches nothing.
- The function does not access the provisioning row object; the caller passes `$row.Department`.

### What this function does NOT do

- Does not resolve or interact with the **IT membership group** (that is the orchestrator + Graph gateway, Tasks 7-12).
- Does not import **Microsoft.Graph**.
- Does not export a public function.
- Does not handle multiple department targets (single-value comparison in v1).
- Does not modify any input.

### File placement

- `src/Modules/BulkIdentityManagement/Private/Test-ProvisioningDepartmentMatch.ps1`

No changes to `.psd1` or `.psm1` export lists (private function auto-loaded by existing dot-source loop).

### Documentation alignment

- **CONTEXT.md** is normative; grill session resolution for Task 6 (trim, API shape, visibility) is recorded there.
- Parent **IMPLEMENTATION-PLAN** Task 6 checkboxes updated when acceptance criteria are met.

### No ADR required

The IT rule is a simple case-insensitive string comparison with no hard-to-reverse tradeoffs.

## Testing Decisions

### What makes a good test

- Assert **observable behavior** of `Test-ProvisioningDepartmentMatch`: return value (`$true` / `$false`) for various Department and Target inputs.
- Do not test private implementation details (e.g. which .NET method is used for comparison).
- Tests import the module (`.psm1`) in **BeforeAll**, same as Tasks 3-5.

### Modules to test

| Module | Test? |
|--------|-------|
| **`Test-ProvisioningDepartmentMatch`** | **Yes** — primary Pester suite for Task 6 |
| **BulkIdentityManagement** manifest | **No** change — function is private, not exported |

### Recommended test scenarios

| Scenario | Department | Target | Expected |
|----------|-----------|--------|----------|
| Exact match (default target) | `'IT'` | (default) | `$true` |
| Lowercase | `'it'` | (default) | `$true` |
| Mixed case | `'It'` | (default) | `$true` |
| Leading/trailing whitespace on Department | `' IT '` | (default) | `$true` |
| Leading/trailing whitespace on Target | `'IT'` | `' IT '` | `$true` |
| Non-matching department | `'Engineering'` | (default) | `$false` |
| Empty string Department | `''` | (default) | `$false` |
| Null Department | `$null` | (default) | `$false` |
| Whitespace-only Department | `'   '` | (default) | `$false` |
| Custom target | `'Finance'` | `'Finance'` | `$true` |
| Custom target case-insensitive | `'finance'` | `'FINANCE'` | `$true` |
| Custom target non-match | `'IT'` | `'Finance'` | `$false` |

### Closure tests

- No `Task7*.Tests.ps1` or later exist.
- No Graph gateway, orchestrator, or entry script symbols in `src/`.
- PSScriptAnalyzer clean on new Task 6 `.ps1` files.

### Prior art

- Task 5 Pester: `Task5.*.Tests.ps1`, module import BeforeAll, `Should -Be`, `Should -BeTrue`/`Should -BeFalse`.
- Task 5 closure tests: `Task5.SubTaskM.Closure.Tests.ps1` — guard against next-task symbols.

## Out of Scope

- **Graph gateway**, real/fake Graph, authentication (**Tasks 7-10**).
- **Orchestrator**, **row outcome** reporting, **dry run** / **apply** wiring (**Tasks 11-13**).
- **IT membership ensure** — the actual group membership add (**Task 12 orchestrator**).
- **IT membership group** resolution by Object ID (**Task 7 gateway contract**).
- Entry script parameters (**Task 13**).
- Multiple department targets or regex matching.
- Removing users from the IT group when Department changes (out of scope for v1 per CONTEXT).

## Further Notes

- **Normative alignment:** If this PRD disagrees with **CONTEXT.md**, **CONTEXT** wins.
- **Task lock:** Implement **Task 6** only; do not start **Task 7** or later in the same delivery unless explicitly expanded.
- **Module naming:** **BulkIdentityManagement** per **CONTEXT**.
- **Promotion path:** If an operator need for a public IT-rule function emerges later, promoting from private to public is a non-breaking change.
