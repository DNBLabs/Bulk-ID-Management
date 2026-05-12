# Implementation plan: Task 1 — Repository foundation

**Spec:** [PRD-Task-1-Foundation.md](PRD-Task-1-Foundation.md). **Normative glossary:** [CONTEXT.md](../../CONTEXT.md). **Parent ordering:** [IMPLEMENTATION-PLAN.md](../IMPLEMENTATION-PLAN.md) (Task 1 only).

**Scope lock:** This plan decomposes **Implementation Plan Task 1** only. It does **not** include README (Task 2), CSV logic (Task 3), CI workflows (Task 14), or any **Microsoft Graph** calls.

**Repo reality (planning snapshot):** The tree may already contain a **BulkIdentityManagement** module under **`src/Modules/`**. Treat sub-tasks as **implement** or **reconcile**: each acceptance bullet must be satisfied before closure, whether files are new or pre-existing.

---

## Overview

Deliver a loadable **BulkIdentityManagement** PowerShell module shell: **root script module**, **module manifest** with **`RequiredModules`** pinning the **rollup** **Microsoft.Graph** to an **exact** PSGallery version, **PowerShell 7.2+** baseline and **Core** edition declaration, empty export lists, and **`Test-ModuleManifest`** success. Extend **`.gitignore`** for **SEC**-class artifacts (secrets, keys, Terraform locals, transcripts, token caches, narrowly-scoped operator-local files). Close with a manual **diff hygiene** check (no tenant secrets, no private keys, no populated tfvars).

---

## Architecture decisions (frozen for this slice)

- **Single authoritative pin surface:** **`RequiredModules`** on the **module manifest** only (no root **`requirements.psd1`** in v1 unless **CONTEXT** is amended later).
- **Rollup dependency:** One **Microsoft.Graph** gallery module version, exact pin (e.g. **ModuleVersion** + **MaximumVersion** match, or equivalent manifest-supported pattern)—no bespoke **Microsoft.Graph.*** submodule list.
- **Runtime:** **`pwsh`**, manifest **minimum 7.2**, **CompatiblePSEditions** includes **Core**; **Windows PowerShell 5.1** unsupported.
- **No public API yet:** Empty **FunctionsToExport** / **CmdletsToExport** / **AliasesToExport**; **Import-Module** must not require **Graph** at import time (do not invoke Graph in **psm1**).
- **Public / Private subfolders:** **Deferred** unless you explicitly choose early layout; reduces empty-directory churn (per PRD).

---

## Dependency graph

```
Resolve Microsoft.Graph version from PSGallery (sub-task A)
    │
    ├── Root script module file (sub-task B)
    │       └── Module manifest with RequiredModules + baseline (sub-task C)
    │
    └── Ignore policy gap analysis + edits (sub-task D)  ← can run parallel to B–C after A or immediately if independent
            │
            └── Closure verification (sub-task E)
```

**Implementation order:** **A → B → C** is strict (manifest needs pin string and **RootModule** target). **D** can start anytime after skimming **SEC** / **CONTEXT**; merge **D** before final **E** so one review pass covers the full Task 1 diff.

---

## Task list

### Phase 1 — Preflight and version pin

## Sub-task A: Record exact Microsoft.Graph version

**Description:** Query **PSGallery** for the current **stable** **Microsoft.Graph** module version at implementation time. Record the chosen version in the implementing PR description (or a short implementation note) so reviewers see why that number was picked. Do not use **`Latest`** or open-ended ranges in the manifest.

**Acceptance criteria:**
- [x] **Find-Module** (or equivalent) output shows the **exact** version string to pin. — Recorded in **`docs/tasks/MicrosoftGraph.psgallery.version.txt`**; enforced by Pester **`tests/Task1.SubTaskA.MicrosoftGraphPinRecord.Tests.ps1`** (optional live check: set **`VALIDATE_PSGRAPH_LIVE=1`**).
- [x] Implementer can justify the pin as **PSGallery stable at merge time** (not a guessed build). — File value **`2.37.0`** matches **`Find-Module Microsoft.Graph`** at authoring time.

**Verification:**
- [x] Manual: Re-run gallery query and confirm **recorded** version string **matches** gallery for that release. — Run **`VALIDATE_PSGRAPH_LIVE=1`** with **`Invoke-Pester`** on the Sub-task A test file before bumping the pin file.

**Dependencies:** None

**Files likely touched:** None required (informational); version lands in sub-task **C**.

**Estimated scope:** XS

---

### Phase 2 — Module shell

## Sub-task B: Root script module (`BulkIdentityManagement.psm1`)

**Description:** Add or reconcile the **root script module** for **BulkIdentityManagement** under the **`src/Modules/`** tree per **CONTEXT**. File must load under **`pwsh`** with **no exported commands** and **no Graph side effects** on import.

**Acceptance criteria:**
- [x] **RootModule** target file exists beside the manifest. — **`BulkIdentityManagement.psm1`** under **`src/Modules/BulkIdentityManagement/`**; sibling check runs in Pester when **`.psd1`** exists.
- [x] Top-of-file module documentation describes purpose and **CONTEXT** as normative (comment-based doc is acceptable for **psm1**). — **`.DESCRIPTION`** includes **`Normative contract: CONTEXT.md at repository root.`**
- [x] **Export-ModuleMember** (or manifest export lists) keeps public surface **empty** for v1 scaffold. — **`Export-ModuleMember -Function @()`**; Pester asserts zero exported functions/cmdlets/aliases on **`-PassThru`** module info.

**Verification:**
- [x] Manual: `Import-Module -Path <path-to-psd1> -Force` succeeds in **PowerShell 7** with **no errors**. — Automated: Pester imports **`.psm1`** via **`Import-Module -Name`** (manifest import deferred to Sub-task C).

**Dependencies:** None (can run parallel with **A** if version for **C** already known; otherwise complete **A** first)

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1`

**Estimated scope:** XS

---

## Sub-task C: Module manifest (`BulkIdentityManagement.psd1`)

**Description:** Add or reconcile the **module manifest**: valid **GUID**, **ModuleVersion** (e.g. **0.1.0** pre-release story per PRD), **PowerShellVersion** **7.2**, **CompatiblePSEditions** **Core**, description referencing **7.2+** / **7.4+ preferred** and **CONTEXT**, explicit empty export arrays, **`RequiredModules`** entry for **Microsoft.Graph** at the **exact** version from **A** using a **non-drifting** version specification.

**Acceptance criteria:**
- [x] **`Test-ModuleManifest`** succeeds on the manifest path. — **`Invoke-ModuleManifestCI.ps1`** + local **`Test-ModuleManifest`** after pinned **`Microsoft.Graph`** install.
- [x] **`RequiredModules`** lists **Microsoft.Graph** only (rollup) at exact pin per **CONTEXT** / PRD. — **`ModuleVersion`** + **`MaximumVersion`** both **`2.37.0`** (from pin file); Pester **`tests/Task1.SubTaskC.BulkIdentityManagementManifest.Tests.ps1`**.
- [x] No root **`requirements.psd1`** introduced as a second authority. — Asserted in Sub-task C Pester; repo search shows none.

**Verification:**
- [x] Manual: `Test-ModuleManifest -Path <manifest>` exits **0**. — Same as CI manifest step / local **`Invoke-ModuleManifestCI`**.
- [x] Manual: `Import-Module` on the manifest does **not** install or call **Graph** (no network requirement for import). — **`psm1`** does not import Graph; **`Import-Module`** on manifest resolves **RequiredModules** only when Graph is already available (CI installs pin for **`Test-ModuleManifest`** only).

**Dependencies:** **A** (version string), **B** (**RootModule** file exists)

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/BulkIdentityManagement.psd1`

**Estimated scope:** S

---

### Phase 3 — Ignore policy

## Sub-task D: `.gitignore` alignment with SEC / PRD

**Description:** Compare current **`.gitignore`** to **PRD** and **SEC** categories. Add **only** justified patterns: e.g. Azure-style CLI cache directories, operator-local script or settings filenames called out in the PRD, without broad “ignore everything” rules. Preserve existing **Terraform** / **`.env`** / key-material / transcript patterns; retain **`!*.tfvars.example`** (or equivalent) if present.

**Acceptance criteria:**
- [ ] New patterns map to a **SEC** category (secrets, credentials, transcripts, local config, token cache).
- [ ] No unrelated binary or build-artifact ignores unless tied to documented risk.
- [ ] **`.tfvars`** remain ignored with safe **example** exception unchanged unless **IDD** / repo policy changes.

**Verification:**
- [ ] Manual: Walk **`git status`** after creating dummy ignored filenames locally (do not commit dummies); confirm they stay **untracked**.

**Dependencies:** None (parallelizable)

**Files likely touched:**
- `.gitignore`

**Estimated scope:** XS–S

---

### Phase 4 — Closure

## Sub-task E: Task 1 closure verification

**Description:** Confirm the **Implementation Plan Task 1** acceptance criteria and PRD **Out of Scope** boundaries: no **README**, no **CI YAML**, no **Graph** API usage, no **Pester** requirement, no secrets in tracked files.

**Acceptance criteria:**
- [ ] **`Test-ModuleManifest`** still succeeds after all edits.
- [ ] **`git diff`** review: no private keys, **client secrets**, populated **`.tfvars`**, or production **Entra** authentication secrets.
- [ ] **Task 1** parent checklist in **IMPLEMENTATION-PLAN** can be marked complete (single PR or coordinated commit).

**Verification:**
- [ ] Manual: `Test-ModuleManifest` + `Import-Module` smoke (repeat **C**/**B**).
- [ ] Manual: Grep / review diff for **tenant ID** usage only if **non-secret** per org policy; default is **avoid** production identifiers in Task 1 entirely.

**Dependencies:** **B**, **C**, **D** complete

**Files likely touched:** None (verification only); optionally **IMPLEMENTATION-PLAN.md** checkboxes for Task 1.

**Estimated scope:** XS

---

## Checkpoint: Task 1 foundation complete

- [ ] **Sub-tasks A–E** acceptance boxes satisfied.
- [ ] **`pwsh`** smoke: manifest valid, module imports.
- [ ] **`.gitignore`** matches **SEC** / PRD intent.
- [ ] Ready for **Task 2** (README) or **Task 3** (CSV) in separate work—**do not** start them inside this closure PR unless explicitly directed.

---

## Parallelization

| Workstream | Can parallel with | Coordination |
|------------|-------------------|----------------|
| **D** (`.gitignore`) | **B** / **C** after **A** | Merge conflicts rare; re-run **E** once combined |
| **A** + **B** | Each other | **C** waits for **A** + **B** |

---

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **RequiredModules** only sets **minimum** version | Medium | Use **ModuleVersion** + **MaximumVersion** (or manifest-supported equivalent) so the pin is **exact**, per PRD story 41. |
| **Import-Module** triggers **Graph** install | High | Keep **psm1** free of **`Connect-MgGraph`** / module loads that hit the network. |
| **Partial scaffold** already in tree | Low | Run **E** as **gap analysis**; do not duplicate manifests with conflicting **GUIDs**. |
| Over-broad **`.gitignore`** | Low | Every new line ties to a **SEC** row or PRD user story category. |

---

## Open questions

- **None** for execution: **CONTEXT** resolved session text already fixes module name, pin location, rollup packaging, and layout under **`src/Modules/BulkIdentityManagement/`**.

---

## Out of scope (reminder)

Everything in **PRD-Task-1-Foundation.md § Out of Scope**—especially **Task 2+**, **Pester** gates for Task 1, **GitHub Actions**, **CSV**, **Graph gateway**, **entry script**.
