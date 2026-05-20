# Implementation plan: Task 5 — UPN composition and collision suffix policy

**Spec:** [PRD-Task-5-UPN-Composition-Collision.md](PRD-Task-5-UPN-Composition-Collision.md). **Normative glossary:** [CONTEXT.md](../../../CONTEXT.md). **Parent ordering:** [IMPLEMENTATION-PLAN.md](../../IMPLEMENTATION-PLAN.md) (Task 5 only). **Tracker:** [DNBLabs/Bulk-ID-Management#4](https://github.com/DNBLabs/Bulk-ID-Management/issues/4).

**Scope lock:** This plan decomposes **Implementation Plan Task 5** only. It does **not** include **IT department rule** (**Task 6**), **Graph gateway** or auth (**Tasks 7–10**), orchestration/reporting (**Tasks 11–13**), entry script (**Task 13**), CI workflow completion (**Task 14**), sample CSV/runbook (**Tasks 16–17**), in-batch UPN claim tracking, or any **Microsoft Graph** calls.

**Repo reality (closure snapshot):** **BulkIdentityManagement** exports **`Import-ProvisioningCsv`**, **`Get-MappedProvisioningIdentity`**, and **`Get-DerivedUserPrincipalName`**. **Private/** holds UPN derivation helpers; **Public/Get-DerivedUserPrincipalName.ps1** orchestrates collision loop with **`-UpnExists`**. Task 5 **Pester**: **`tests/Task5*.Tests.ps1`** (**28** tests, includes **`Task5.Derivation.Security.Tests.ps1`**). No **Microsoft.Graph** in Task 5 code. CSV **UserPrincipalName** bounded to **113** chars; domain mismatch errors do not echo untrusted domain text.

---

## Overview

Deliver **`Get-DerivedUserPrincipalName`**: a fail-closed, pure **Identity derivation** boundary that composes or parses **UserPrincipalName** per **CONTEXT**, runs a bounded collision loop behind mandatory **`-UpnExists`**, and returns canonical lowercase UPN plus **AttemptCount**. Wire the command into **BulkIdentityManagement** exports and add dedicated **Pester** suites. Do **not** start **Task 6** or later.

---

## Architecture decisions (frozen for this slice)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Public API** | **`Get-DerivedUserPrincipalName`** only | Single deep module entry per PRD / **CONTEXT** |
| **Inputs** | **ProvisioningRow** + **MappedProvisioningIdentity** + **TenantDomainSuffix** + **UpnExists** | Task 4 boundary preserved; no internal re-map |
| **Failure mode (row validation)** | **`System.InvalidOperationException`** with physical line in message | Matches Task 4; orchestrator → **row outcome** **failed** |
| **Failure mode (bad parameters)** | **`System.ArgumentException`** for null row/mapped, missing properties, **MaximumUpnCandidates** out of range | Distinguish caller mistakes from row data |
| **`-UpnExists` throws** | Propagate unchanged | Graph/transient handling belongs in apply layer |
| **Output type** | **PSCustomObject**: **UserPrincipalName**, **SourceLineNumber**, **AttemptCount** | PRD / grill session |
| **Suffix placement** | Digits **`2`**, **`3`**, … appended to **end of local part** (no separator) | **CONTEXT** option A |
| **CSV UPN** | Overrides composition; same collision loop on parsed local part | **CONTEXT** option B |
| **Domain suffix param** | Accept **`contoso.com`** or **`@contoso.com`**; normalize to domain without **`@`** | **CONTEXT** option C |
| **CSV domain mismatch** | Fail row (case-insensitive compare to normalized suffix) | **CONTEXT** option A |
| **Nickname local part** | **`MappedProvisioningIdentity.MailNickname`** verbatim | Task 4 already normalized |
| **Canonical UPN** | Full address lowercase (local + **`@`** + domain) | Exists stubs and Entra consistency |
| **Collision cap** | **`-MaximumUpnCandidates`** default **10**, range **1**–**99** | Counts base + suffixed attempts |
| **Exists gate** | Full UPN string only via **`-UpnExists`** | No mailNickname-only loop in Task 5 |
| **In-batch duplicates** | Out of scope | Orchestrator (Task 12+) |
| **Layout** | New **Private/** helpers + **Public/Get-DerivedUserPrincipalName.ps1** | Matches Task 3–4 |
| **Graph isolation** | No **Microsoft.Graph** in Task 5 scripts or Task 5 **Pester** | Offline CI |

**Reference examples (stub **`-UpnExists`** returns **true** only for listed UPNs):**

| Path | MailNickname / CSV UPN | Suffix param | Taken UPNs | Result | AttemptCount |
|------|------------------------|--------------|------------|--------|--------------|
| Nickname | jane.doe | contoso.com | jane.doe@contoso.com | jane.doe2@contoso.com | 2 |
| Nickname | ada.lovelace | @contoso.com | (none) | ada.lovelace@contoso.com | 1 |
| CSV | Custom.Alias@contoso.com | contoso.com | custom.alias@contoso.com | custom.alias2@contoso.com | 2 |
| CSV | ada@fabrikam.com | contoso.com | — | **fail** domain mismatch | — |
| Nickname | jane.doe | contoso.com | base…jane.doe10@… all taken | **fail** cap | — |

---

## Dependency graph

```
Sub-task A: Private tenant domain suffix normalization
    │
    ├── Sub-task B: Private CSV UserPrincipalName parse and validate
    │       │
    │       └── Sub-task C: Private UPN candidate builder (local part + suffix index + canonical lowercase)
    │               │
    │               └── Sub-task D: Private base local part resolution (CSV vs MailNickname)
    │                       │
    │                       └── Sub-task E: Public Get-DerivedUserPrincipalName (collision loop)
    │                               │
    │                               └── Sub-task F: Manifest + Export-ModuleMember wiring
    │                                       │
    │                                       ├── Sub-task G: Pester — nickname-built UPN and suffix param
    │                                       │
    │                                       ├── Sub-task H: Pester — collision progression and AttemptCount
    │                                       │
    │                                       ├── Sub-task I: Pester — CSV override, domain mismatch, invalid UPN
    │                                       │
    │                                       ├── Sub-task J: Pester — cap exceeded, parameter bounds, UpnExists throw
    │                                       │
    │                                       ├── Sub-task K: Pester — immutability + optional security bounds
    │                                       │
    │                                       └── Sub-task L: Pester — export smoke + Import→Map→Derive integration
    │                                               │
    │                                               └── Sub-task M: Closure + parent plan checkboxes
```

**Implementation order:** **A → B → C → D → E → F → G → H → I → J → K → L → M** (strict). **B** (CSV UPN parsing) is the main validation risk—cover with table-driven cases in **I** via the public cmdlet.

---

## Task list

### Phase 1 — Private foundations

## Sub-task A: Normalize tenant domain suffix

**Description:** Add a private function (e.g. **`Get-NormalizedProvisioningTenantDomain`**) that trims **TenantDomainSuffix**, strips a single leading **`@`**, rejects empty/whitespace-only result, and optionally enforces a maximum length constant (add **`MaxProvisioningTenantDomainSuffixLength`** to **ProvisioningIdentity.Constants.ps1** if not present—e.g. **255**). No Graph; no row awareness.

**Acceptance criteria:**
- [x] **`contoso.com`** and **`@contoso.com`** normalize to **`contoso.com`**. — `Get-NormalizedProvisioningTenantDomain`; `Task5.UpnComposition.Tests.ps1`.
- [x] Empty or whitespace-only suffix throws **`ArgumentException`** (parameter error, not row line). — `Task5.Derivation.Security.Tests.ps1`.

**Verification:**
- [x] Exercised via **Sub-task G** through public cmdlet; optional direct unit only if debugging.

**Dependencies:** None (Task 4 complete)

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Private/Get-NormalizedProvisioningTenantDomain.ps1` (example name)
- `src/Modules/BulkIdentityManagement/Private/ProvisioningIdentity.Constants.ps1` (optional max length)

**Estimated scope:** XS

---

## Sub-task B: Parse and validate CSV UserPrincipalName

**Description:** Add a private function (e.g. **`Get-ProvisioningCsvUpnParts`**) that accepts trimmed CSV **UserPrincipalName**, **normalized tenant domain**, and **SourceLineNumber**. Enforce exactly one **`@`**, non-empty local part and domain after trim, domain equals normalized suffix (case-insensitive). Return local part and domain for collision loop. On violation, throw **`InvalidOperationException`** citing physical line.

**Acceptance criteria:**
- [x] **`ada@contoso.com`** with suffix **`contoso.com`** → local **`ada`**, domain **`contoso.com`** (case preserved until canonical compose in **C**).
- [x] **`ada@fabrikam.com`** with suffix **`contoso.com`** → throw with line number.
- [x] **`not-an-email`**, **`a@b@c`**, **`@contoso.com`**, **`ada@`** → throw with line number.

**Verification:**
- [x] Covered by **Sub-task I** via public cmdlet. — `Task5.UpnCsvOverride.Tests.ps1`.

**Dependencies:** Sub-task A

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Private/Get-ProvisioningCsvUpnParts.ps1` (example name)

**Estimated scope:** S

---

## Sub-task C: Build canonical UPN candidate

**Description:** Add a private function (e.g. **`Get-CanonicalProvisioningUpnCandidate`**) that accepts **localPart** (string), **normalizedDomain**, and **suffixIndex** (**0** = base only; **1** = append **`2`**; **2** = append **`3`**; … per **CONTEXT** mapping from attempt index to digit suffix). Compose **`{localPart}@{domain}`**, lowercase entire string, return UPN. Validate combined length against Entra-oriented max (add **`MaxProvisioningUserPrincipalNameLength`** constant, e.g. **113**, if implementing bounds).

**Acceptance criteria:**
- [x] Base: **`jane.doe`** + **`contoso.com`** → **`jane.doe@contoso.com`**.
- [x] First collision index: **`jane.doe`** → local **`jane.doe2`** → **`jane.doe2@contoso.com`**.
- [x] **`Custom.Alias`** + domain → **`custom.alias@contoso.com`** after lowercase.

**Verification:**
- [x] Covered by **Sub-task G** and **H**. — `Task5.UpnComposition.Tests.ps1`, `Task5.UpnCollision.Tests.ps1`.

**Dependencies:** Sub-task A

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Private/Get-CanonicalProvisioningUpnCandidate.ps1` (example name)
- `src/Modules/BulkIdentityManagement/Private/ProvisioningIdentity.Constants.ps1` (optional UPN max)

**Estimated scope:** S

---

## Sub-task D: Resolve base local part

**Description:** Add a private function (e.g. **`Get-ProvisioningUpnBaseLocalPart`**) that accepts **ProvisioningRow**, **MappedProvisioningIdentity**, and normalized domain. If row has **UserPrincipalName** property, call **B** and return CSV local part; else return **MappedProvisioningIdentity.MailNickname** verbatim (validate non-empty; throw **`InvalidOperationException`** with line if missing/empty). Validate mapped object has **MailNickname** and **SourceLineNumber** aligned with row (throw **`ArgumentException`** if mapped object malformed).

**Acceptance criteria:**
- [x] Row without **UserPrincipalName** uses **MailNickname** from mapped identity.
- [x] Row with **UserPrincipalName** does not read **MailNickname** for base local part.
- [x] Null/empty **MailNickname** when required → row failure with line number.

**Verification:**
- [x] Covered by **G**, **I**, **K**.

**Dependencies:** Sub-tasks B, mapped identity shape from Task 4

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Private/Get-ProvisioningUpnBaseLocalPart.ps1` (example name)
- `src/Modules/BulkIdentityManagement/Private/Test-MappedProvisioningIdentityBoundary.ps1` (example name, optional)

**Estimated scope:** S

---

### Phase 2 — Public orchestration and exports

## Sub-task E: Public `Get-DerivedUserPrincipalName`

**Description:** Add **`Public/Get-DerivedUserPrincipalName.ps1`**. Validate mandatory parameters; **`-MaximumUpnCandidates`** default **10**, validate **1**–**99**. Call **A** → **D** for base local part and domain. Loop attempt index **0** .. **MaximumUpnCandidates − 1**: build candidate with **C**, invoke **`-UpnExists`** with canonical UPN (increment **AttemptCount** each call); on **false**, return **PSCustomObject** with **UserPrincipalName**, **SourceLineNumber**, **AttemptCount**. On exhaustion, throw **`InvalidOperationException`** citing line and cap. Do not mutate inputs; do not call **`Get-MappedProvisioningIdentity`**.

**Acceptance criteria:**
- [x] Implements PRD processing order and **CONTEXT** collision rules.
- [x] **`-UpnExists`** mandatory; script block exceptions propagate.
- [x] **AttemptCount** includes successful probe.

**Verification:**
- [x] **Sub-tasks G–J** green.

**Dependencies:** Sub-tasks A–D

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Public/Get-DerivedUserPrincipalName.ps1`

**Estimated scope:** S

---

## Sub-task F: Manifest and module export wiring

**Description:** Add **`Get-DerivedUserPrincipalName`** to **FunctionsToExport** in **BulkIdentityManagement.psd1** and **Export-ModuleMember** in **BulkIdentityManagement.psm1**. Dot-source order unchanged (Private then Public).

**Acceptance criteria:**
- [x] **`Import-Module`** exposes **`Get-DerivedUserPrincipalName`**.
- [x] No new **RequiredModules** or Graph imports.

**Verification:**
- [x] **Sub-task L** manifest test.

**Dependencies:** Sub-task E

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/BulkIdentityManagement.psd1`
- `src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1`

**Estimated scope:** XS

---

### Phase 3 — Pester (no Graph)

## Sub-task G: Pester — nickname-built UPN and domain suffix normalization

**Description:** Add **`tests/Task5.UpnComposition.Tests.ps1`**: minimal row + mapped fixtures; **`-UpnExists { $false }`**; assert lowercase UPN from **MailNickname** + **`contoso.com`** and **`@contoso.com`**; **AttemptCount** **1**. Reuse **BeforeAll** module import pattern from Task 4.

**Acceptance criteria:**
- [x] **`ada.lovelace`** → **`ada.lovelace@contoso.com`**.
- [x] **AttemptCount** and **SourceLineNumber** asserted on success object.

**Verification:**
- [x] `Invoke-Pester` on file green.

**Dependencies:** Sub-task F

**Files likely touched:**
- `tests/Task5.UpnComposition.Tests.ps1`

**Estimated scope:** S

---

## Sub-task H: Pester — collision suffix progression

**Description:** Add **`tests/Task5.UpnCollision.Tests.ps1`**: hashtable- or script-based **`-UpnExists`** returning **true** for taken UPNs. Cases: base taken → **`…2@`**; base + **2** taken → **`…3@`**; **AttemptCount** matches probe count. Include local part that already ends with digit (e.g. **`ada2`** → **`ada22@`** when base taken).

**Acceptance criteria:**
- [x] Suffix **`2`** is first collision, not **`1`**.
- [x] PRD table case **jane.doe** → **jane.doe2@contoso.com** with **AttemptCount** **2**.

**Verification:**
- [x] `Invoke-Pester` on file green.

**Dependencies:** Sub-task F

**Files likely touched:**
- `tests/Task5.UpnCollision.Tests.ps1`

**Estimated scope:** S

---

## Sub-task I: Pester — CSV UserPrincipalName override and validation failures

**Description:** Add **`tests/Task5.UpnCsvOverride.Tests.ps1`**: row with **UserPrincipalName**; collision on local part; domain mismatch throw with **physical line**; invalid shapes (**no @**, **double @**, empty local).

**Acceptance criteria:**
- [x] **Custom.Alias@contoso.com** collision → **custom.alias2@contoso.com**.
- [x] **ada@fabrikam.com** throws **InvalidOperationException** with line.
- [x] Nickname path not used when CSV UPN present (stub proves composition skipped).

**Verification:**
- [x] `Invoke-Pester` on file green.

**Dependencies:** Sub-task F

**Files likely touched:**
- `tests/Task5.UpnCsvOverride.Tests.ps1`

**Estimated scope:** S

---

## Sub-task J: Pester — cap exceeded, parameter validation, UpnExists propagation

**Description:** Add **`tests/Task5.UpnCollisionLimits.Tests.ps1`**: stub all candidates taken → throw mentions cap and line; **`-MaximumUpnCandidates 1`** only tries base; **`-MaximumUpnCandidates 0`** or **100** throws **ArgumentException** at parameter validation; **`-UpnExists { throw 'graph down' }`** propagates without wrapping.

**Acceptance criteria:**
- [x] Cap exceeded message references **MaximumUpnCandidates** or attempt limit and **SourceLineNumber**.
- [x] **UpnExists** throw is not **InvalidOperationException** with “physical line” unless original was that type.

**Verification:**
- [x] `Invoke-Pester` on file green.

**Dependencies:** Sub-task F

**Files likely touched:**
- `tests/Task5.UpnCollisionLimits.Tests.ps1`

**Estimated scope:** S

---

## Sub-task K: Pester — immutability and security bounds

**Description:** Add **`tests/Task5.UpnImmutability.Tests.ps1`**: row and mapped object unchanged after derive (property bag comparison). Optional **`tests/Task5.Derivation.Security.Tests.ps1`**: oversized CSV **UserPrincipalName** or **TenantDomainSuffix** rejected at boundary (mirror Task 4 security tests).

**Acceptance criteria:**
- [x] Input objects not mutated. — `Task5.UpnImmutability.Tests.ps1`.
- [x] If security file added: bounded string rejection before collision loop. — `Task5.Derivation.Security.Tests.ps1`; row boundary + sanitized domain mismatch errors.

**Verification:**
- [x] `Invoke-Pester` on file(s) green.

**Dependencies:** Sub-task F

**Files likely touched:**
- `tests/Task5.UpnImmutability.Tests.ps1`
- `tests/Task5.Derivation.Security.Tests.ps1` (optional)

**Estimated scope:** XS–S

---

## Sub-task L: Pester — export smoke and Import→Map→Derive integration

**Description:** Add **`tests/Task5.SubTaskL.ModuleExport.Tests.ps1`**: **FunctionsToExport** contains **`Get-DerivedUserPrincipalName`**. Integration: **TestDrive** CSV with optional **UserPrincipalName** column → **`Import-ProvisioningCsv`** → **`Get-MappedProvisioningIdentity`** → **`Get-DerivedUserPrincipalName`** with **`UpnExists { $false }`**. Scan Task 5 **`.ps1`** for **Microsoft.Graph** / **`Connect-MgGraph`**.

**Acceptance criteria:**
- [x] Manifest export list includes new function.
- [x] Pipeline smoke passes.
- [x] No Graph references in Task 5 source files.

**Verification:**
- [x] `Invoke-Pester` on file green.

**Dependencies:** Sub-task F

**Files likely touched:**
- `tests/Task5.SubTaskL.ModuleExport.Tests.ps1`

**Estimated scope:** XS–S

---

### Phase 4 — Closure

## Sub-task M: Task 5 closure and parent plan update

**Description:** Run full Task 5 **Pester** subset + **PSScriptAnalyzer** on new **`.ps1`** files. Manual smoke in **pwsh** (map + derive with **`UpnExists { $false }`** and collision stub). Update **`docs/IMPLEMENTATION-PLAN.md`** Task 5 acceptance/verification checkboxes. Update this plan’s checkboxes. Do **not** check Task 6+ boxes or add IT rule / gateway code.

**Acceptance criteria:**
- [x] Parent plan Task 5 acceptance criteria satisfied (CSV override, injectable exists, bounded attempts tested).
- [x] No Task 6+ code or tests introduced (no **`Task6*.Tests.ps1`**, no IT rule symbols).
- [x] Issue **#4** ready for review per team process.

**Verification:**
- [x] `Invoke-Pester` **`tests/Task5*.Tests.ps1`** green (**31** tests).
- [x] Manual: derive with collision stub for one row (covered by closure smoke test).
- [x] **`tests/Task5.SubTaskM.Closure.Tests.ps1`**: parent plan Task 5 boxes, no Task 6 files.

**Dependencies:** Sub-tasks G, H, I, J, K, L

**Files likely touched:**
- `docs/IMPLEMENTATION-PLAN.md`
- `docs/tasks/task-5/PLAN-Task-5-UPN-Composition-Collision.md` (checkboxes)
- `tests/Task5.SubTaskM.Closure.Tests.ps1` (optional)

**Estimated scope:** XS

---

## Checkpoints

### Checkpoint: After Sub-task D
- [x] Base local part from CSV and from **MailNickname** verifiable in **pwsh** scratch calls.
- [x] CSV domain mismatch throws with physical line before public cmdlet is wired.
- [x] Proceed to **E** only when **B**/**C** match **CONTEXT** examples.

### Checkpoint: After Sub-task F
- [x] **`Get-DerivedUserPrincipalName`** callable from imported **`.psm1`**.
- [x] **`UpnExists { $false }`** returns **`ada.lovelace@contoso.com`** for standard mapped fixture.
- [x] No Graph calls in new scripts.

### Checkpoint: Task 5 complete (after Sub-task M)
- [x] **`Invoke-Pester`** passes for **G**–**L** (and optional **M**) without live tenant. — **31** Task 5 tests green.
- [x] **IMPLEMENTATION-PLAN** Task 5 boxes updated.
- [x] Ready for **Task 6** (**IT department rule**)—do **not** start Task 6 in this delivery. — No Task 6 code or tests introduced.
- [x] Task 5 **src** scripts: PSScriptAnalyzer **0** Warning/Error (this turn). Repo-wide CI script still reports **1** pre-existing Warning in `Task1.SubTaskC.BulkIdentityManagementManifest.Tests.ps1` (BOM).

---

## Parallelization

| Safe parallel | Must be sequential |
|---------------|-------------------|
| **G**, **H**, **I**, **J**, **K** after **F** | **A→B→C→D→E→F** |
| Fixture authoring while building **B–D** | **B** before CSV path in **D**/**E** |
| **L** manifest smoke parallel with **G–K** after **F** | **C** before **E** collision loop |

---

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Suffix index vs digit **`N`** off-by-one | High | Table-driven **H** tests; document mapping in **C** (attempt **0** = base, attempt **1** = suffix **2**) |
| **MaximumUpnCandidates** interpreted as “suffix count” vs “total probes” | Medium | Align with **CONTEXT** (total candidates); test **J** with **1** and **10** |
| **UpnExists** stub case sensitivity | Medium | Always pass lowercase canonical UPN from **C**; document in function comment |
| **PSScriptAnalyzer** on new scripts | Low | Run in **M**; match Task 4 help/comment style |
| Accidental Task 6+ / Graph code | Medium | **M** closure scan; scope lock in PR |
| Long CSV UPN cells | Medium | Optional **K** security bounds; constants file |
| Calling **`Get-MappedProvisioningIdentity`** inside derive | Medium | **M** closure grep; PRD explicit ban |

---

## Open questions

- **None blocking** — contract frozen in **CONTEXT** and [PRD-Task-5-UPN-Composition-Collision.md](PRD-Task-5-UPN-Composition-Collision.md). If Entra enforces a UPN length shorter than chosen **`MaxProvisioningUserPrincipalNameLength`**, adjust constant and security tests in implementation PR (ADR only if behavior change is hard to reverse).

---

## Human review gate

Maintainer should confirm this plan (or request edits) before implementation spend.

**After approval:** Implement **A → M** in order; update this plan’s checkboxes as sub-tasks complete.

**Parent IMPLEMENTATION-PLAN mapping:** Task 5 acceptance maps to **E** (behavior), **F** (export), **H**/**J** (collision + bound), **I** (CSV override), **M** (closure).
