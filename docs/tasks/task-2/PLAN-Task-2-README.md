# Implementation plan: Task 2 — README aligned with documentation authority

**Spec:** [PRD-Task-2-README.md](PRD-Task-2-README.md). **Normative glossary:** [CONTEXT.md](../../../CONTEXT.md). **Parent ordering:** [IMPLEMENTATION-PLAN.md](../../IMPLEMENTATION-PLAN.md) (Task 2 only).

**Scope lock:** This plan decomposes **Implementation Plan Task 2** only. It does **not** include CSV parsing (Task 3), name or identity derivation (Tasks 4–5), IT rules (Task 6), Graph gateway or auth work (Tasks 7–10), orchestration/reporting (Tasks 11–13), CI workflow completion (Task 14), optional tenant-mutating workflow work (Task 15), sample CSV/runbook/lab checklist work (Tasks 16–17), or any **Microsoft Graph** calls.

**Repo reality (planning snapshot):** Task 1 foundation exists: the **BulkIdentityManagement** module scaffold and manifest are present under **`src/Modules/BulkIdentityManagement/`**, and the repo may already contain validate-only CI foundation. Treat README wording as **document current truth plus boundaries**, not as a promise that provisioning commands exist.

---

## Overview

Deliver a root **README.md** that serves as the repository authority landing page: it opens with **CONTEXT.md** as the normative glossary and behavioral contract, links the current design and planning documents, summarizes **CI scope** versus **apply path**, states **dry-run before mutating apply**, and documents certificate/private key material outside the repository with **client secret** not the default path. Close with link/render review and checklist updates; do not implement or document working apply commands.

---

## Architecture decisions (frozen for this slice)

- **README is a router, not the contract:** **`CONTEXT.md`** remains normative; README points there first and summarizes only the highest-signal constraints.
- **Thin landing page:** No full operator runbook, sample CSV, entry-script parameter matrix, or provisional apply commands in Task 2.
- **Actual root-relative links:** README links use the current repository paths from the root, including **`docs/Design/`** for **HLD**, **IDD**, and **SEC**.
- **Current status is explicit:** README states implementation is in progress and links **`docs/IMPLEMENTATION-PLAN.md`** for task status.
- **Security posture is explicit:** No real tenant identifiers, certificate thumbprints, client IDs, object IDs, private-key paths, or secrets are added.

---

## Dependency graph

```
Confirm source paths and README structure (sub-task A)
    │
    ├── Authority and document map content (sub-task B)
    │       │
    │       ├── CI vs apply / auth safety content (sub-task C)
    │       │       │
    │       │       └── Current status + not-yet-implemented boundaries (sub-task D)
    │       │               │
    │       │               └── Link, render, and hygiene verification (sub-task E)
    │       │                       │
    │       │                       └── Closure checklist updates (sub-task F)
```

**Implementation order:** **A → B → C → D → E → F**. The content tasks are small, but writing them sequentially prevents the README from drifting into a runbook or later-task implementation.

---

## Task list

### Phase 1 — README structure

## Sub-task A: Confirm source paths and README outline

**Description:** Reconfirm the Task 2 PRD, **CONTEXT**, parent implementation plan, design document locations, and existing root README status. Draft the README section order before writing content.

**Acceptance criteria:**
- [x] README section outline starts with **CONTEXT.md** as the first authority reference. — Added a root README outline whose first Markdown link points to **`CONTEXT.md`**.
- [x] Planned links use current root-relative paths for **CONTEXT**, **PRD**, **HLD**, **IDD**, **SEC**, **Implementation Plan**, and **init-project**. — Added root-relative outline links to all required source documents.
- [x] Outline excludes runbook-style apply commands, sample CSV instructions, and Task 3+ implementation details. — Kept the README as section-order scaffolding with placeholders for later Task 2 prose only.

**Verification:**
- [x] Manual: Compare planned links against files present in the repository. — Verified the required README outline links exist with an inline PowerShell documentation-structure check.
- [x] Manual: Confirm no README content has been written for Task 3+ behavior. — Verified the outline omits later-task command examples and provisioning implementation details.

**Dependencies:** None

**Files likely touched:**
- `README.md`

**Estimated scope:** XS

---

### Phase 2 — Authority landing page content

## Sub-task B: Write authority and document map

**Description:** Create or reconcile the top of **README.md** so readers see **CONTEXT.md** first, understand it is normative, and can navigate to the parent **PRD**, **HLD**, **IDD**, **SEC**, implementation plan, and informal **init-project** background.

**Acceptance criteria:**
- [x] README opens with a clear pointer to **CONTEXT.md** as the normative glossary and behavioral contract. — Kept the first README guidance as a direct link to **`CONTEXT.md`** with normative wording.
- [x] README states **init-project** is background only and **CONTEXT** wins on conflicts. — Added conflict-ordering language and labeled **`docs/init-project.txt`** as background only.
- [x] README includes a concise document map with working relative links. — Preserved the root-relative document map for PRD, HLD, IDD, SEC, implementation plan, and background brief.

**Verification:**
- [x] Manual: README renders with the first visible guidance pointing to **CONTEXT.md**. — Verified with the Task 2.2 inline README authority check.
- [x] Manual: Click or inspect all document-map links from repo root. — Verified each document-map link target exists from the repository root.

**Dependencies:** Sub-task A

**Files likely touched:**
- `README.md`

**Estimated scope:** XS

---

## Sub-task C: Document CI scope, apply path, and credential safety

**Description:** Add the operational safety summary: default **CI validation gates** are validate-only and do not call **Microsoft Graph**; real tenant mutation belongs to explicit **apply** paths; operators must dry-run before mutating apply; certificate/private key material stays outside the repository; **client secret** is not the default.

**Acceptance criteria:**
- [x] README states **CI validation gates** and explicitly says default CI does **not** call **Microsoft Graph**. — Added validate-only CI wording naming **PSScriptAnalyzer**, **Pester**, and no default **Microsoft Graph** calls.
- [x] README distinguishes **CI scope** from the tenant-mutating **apply path**. — Added separate CI scope and explicit tenant-mutating apply path language.
- [x] README states **dry-run before mutating apply**. — Documented dry-run before mutating apply as the required operator habit.
- [x] README states certificate/private key material remains outside the repo and **client secret** is not the default path. — Added certificate/private-key outside-repository wording and clarified client secret is not the default.

**Verification:**
- [x] Manual: Search README for **Microsoft Graph**, **dry run**, **certificate**, and **client secret** statements. — Verified with the Task 2.3 inline README CI/apply/credential check.
- [x] Manual: Confirm no tenant credentials, private-key paths, or real identifiers are present. — Verified the README omits prohibited secret markers, real identifier examples, and Graph command examples.

**Dependencies:** Sub-task B

**Files likely touched:**
- `README.md`

**Estimated scope:** XS

---

## Sub-task D: Document current implementation status and boundaries

**Description:** Add a brief current-status section that acknowledges the Task 1 module foundation and pinned dependency manifest, then clearly marks provisioning behavior as later work.

**Acceptance criteria:**
- [x] README mentions the **BulkIdentityManagement** module scaffold and **PowerShell 7.2+** / **7.4+ preferred** baseline without claiming public provisioning commands exist. — Added current-status wording for the scaffold path and PowerShell baseline without command examples.
- [x] README notes **Microsoft.Graph** is pinned in the repository module manifest and not floating **Latest**. — Documented the pinned **`Microsoft.Graph`** manifest policy without introducing a second dependency source.
- [x] README includes a short **not yet implemented** boundary for CSV parsing, identity derivation, Graph gateway/auth, apply orchestration, sample CSV, runbook, and lab checklist. — Added a concise boundary pointing these behaviors to later implementation-plan tasks.

**Verification:**
- [x] Manual: Confirm README does not contain unsupported command examples or parameter documentation for future entry scripts. — Verified with the Task 2.4 inline README status/boundary check.
- [x] Manual: Confirm future work points back to **`docs/IMPLEMENTATION-PLAN.md`** rather than duplicating the full plan. — README links future work to the implementation plan and keeps the boundary summary short.

**Dependencies:** Sub-task C

**Files likely touched:**
- `README.md`

**Estimated scope:** XS

---

### Phase 3 — Verification and closure

## Sub-task E: Link, render, and hygiene verification

**Description:** Review the completed README as a Markdown artifact and verify links, scope, and secret hygiene.

**Acceptance criteria:**
- [x] README renders cleanly in Markdown preview or plain Markdown review. — Inspected the completed Markdown structure and verified the project heading plus completed Task 2 prose.
- [x] All relative links resolve from the repository root. — Verified every README relative link target exists from the repository root.
- [x] README contains no real **Entra tenant** identifiers, **client IDs**, certificate thumbprints, private-key paths, group object IDs, client secrets, or populated local configuration examples. — Verified no high-signal secret markers, real identifier examples, or unsupported Graph/apply command details are present.

**Verification:**
- [x] Manual: Preview README or inspect rendered Markdown. — Reviewed **`README.md`** as plain Markdown and confirmed no Task 2 placeholder prose remains.
- [x] Manual: Open or inspect each relative link. — Used an inline PowerShell verification check to inspect all Markdown links.
- [x] Manual: Search README for high-signal secret markers and unsupported command examples. — Used the same verification check to scan for tenant/config secret markers and unsupported Graph/apply commands.

**Dependencies:** Sub-task D

**Files likely touched:**
- `README.md`

**Estimated scope:** XS

---

## Sub-task F: Closure checklist updates

**Description:** After README verification passes, update this Task 2 plan and the parent **Implementation Plan** Task 2 checkboxes with brief one-sentence summaries of the completed work.

**Acceptance criteria:**
- [x] Sub-tasks A–E in this plan are marked complete with concise summaries. — Confirmed README outline, authority map, CI/apply/auth safety, status boundary, and artifact verification subtasks are all checked with evidence notes.
- [x] Parent **Implementation Plan** Task 2 acceptance and verification boxes are marked complete with concise summaries. — Updated the parent Task 2 acceptance and verification checklist entries after README verification passed.
- [x] No Task 3+ checklist entries are changed. — Verified parent Task 3 remains unstarted and no later-task checklist entries were marked.

**Verification:**
- [x] Manual: Re-open this plan and parent implementation plan to confirm Task 2 status is updated. — Rechecked the Task 2 plan and parent Task 2 section with the closure-state verification command.
- [x] Manual: Review diff to ensure only Task 2 documentation/planning files changed. — Closure scope remained limited to README and Task 2 planning/parent checklist documentation.

**Dependencies:** Sub-task E

**Files likely touched:**
- `docs/tasks/task-2/PLAN-Task-2-README.md`
- `docs/IMPLEMENTATION-PLAN.md`

**Estimated scope:** XS

---

## Checkpoint: Task 2 README complete

- [x] **README.md** opens with **CONTEXT.md** as normative. — README starts with a **`CONTEXT.md`** link and authority statement.
- [x] **CI validation gates** and **no Graph in default CI** are explicit. — README documents validate-only **PSScriptAnalyzer** / **Pester** gates and no default **Microsoft Graph** calls.
- [x] Certificate material outside the repo and **client secret** not default are explicit. — README states certificate/private-key material stays outside the repo and client secret is not the default.
- [x] README links render and resolve relative to the repository root. — README artifact verification confirmed all relative links resolve.
- [x] Task 2 checklist state is updated in both this plan and the parent **Implementation Plan**. — Closure updated both checklist locations for Task 2.
- [x] No Task 3+ behavior, tests, scripts, workflows, sample CSVs, or Graph calls were introduced. — Verification confirmed Task 3 remains unstarted and README contains no unsupported provisioning commands.

---

## Parallelization

No meaningful parallelization for Task 2. The README is a single document with a small dependency chain; sequential edits reduce the risk of contradicting **CONTEXT** or implying future behavior exists.

---

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| README implies provisioning commands exist before Task 13 | Medium | Keep README as a thin landing page; no apply command examples or parameter matrix. |
| README duplicates or drifts from **CONTEXT** | Medium | Link **CONTEXT** first and summarize, not restate, the glossary. |
| Relative links break after task-folder reorganization | Low | Verify links from the repository root during Sub-task E. |
| Secret-like sample values appear in documentation | Medium | Use no real identifiers; prefer prose over examples for Task 2. |

---

## Open questions

- None for execution. The Task 2 PRD and prior grilling decisions fix the README as a thin authority landing page, not a runbook.

---

## Out of scope (reminder)

Everything after **Implementation Plan Task 2**, especially **Task 3** CSV logic, provisioning behavior, Graph/auth work, entry scripts, default CI completion, optional tenant-mutating workflows, sample CSVs, runbooks, and lab checklists.
