# PRD: Task 5 — UPN composition and collision suffix policy

**Normative glossary:** [CONTEXT.md](../../../CONTEXT.md). **Parent product PRD:** [PRD.md](../../PRD.md). **Implementation slice:** [IMPLEMENTATION-PLAN.md](../../IMPLEMENTATION-PLAN.md) — Task 5 only.

**Design references:** [HLD.md](../../HLD.md), [SEC.md](../../SEC.md). **Background only:** [init-project.txt](../../init-project.txt).

**Issue tracker:** Published as [DNBLabs/Bulk-ID-Management#4](https://github.com/DNBLabs/Bulk-ID-Management/issues/4) with the **`ready-for-agent`** label.

**Prerequisites:** Task 3 **`Import-ProvisioningCsv`** (**provisioning row** objects); Task 4 **`Get-MappedProvisioningIdentity`** (**mapped provisioning identity** objects).

---

## Problem Statement

Task 4 delivers **mapped provisioning identity** objects with a normalized **MailNickname**, but **bulk provisioning** still cannot assign a deterministic **UserPrincipalName** per **provisioning row** before **apply**. Operators need UPNs built from **MailNickname** plus a configured **tenant domain suffix** (non-secret), optional full **UserPrincipalName** CSV overrides, and a **numeric suffix collision** strategy when a UPN is already taken—without calling **Microsoft Graph** in unit tests or default **CI validation gates**. Without Task 5, Task 7+ orchestration would duplicate derivation rules or couple suffix logic to Graph HTTP, making **Pester** slow and brittle.

## Solution

Implement **Identity derivation** as a pure deep module inside **BulkIdentityManagement**: a public **`Get-DerivedUserPrincipalName`** command that accepts a **provisioning row**, a **mapped provisioning identity** (Task 4 output), a **tenant domain suffix**, and a mandatory injectable **`-UpnExists`** script block (full UPN in, **bool** out). The command composes or parses UPN candidates, loops with bounded attempts when **`-UpnExists`** returns true, and returns a canonical lowercase **UserPrincipalName** plus **AttemptCount**. Row-level failures throw **`System.InvalidOperationException`** citing **SourceLineNumber**; **`-UpnExists`** exceptions propagate unchanged. The command does **not** call **`Get-MappedProvisioningIdentity`** internally and does **not** import **Microsoft.Graph**.

## User Stories

1. As an **identity operator**, I want **UserPrincipalName** built from **MailNickname** plus my tenant’s verified domain suffix, so that UPNs are consistent and the suffix is not stored as a secret in the repo.
2. As an **identity operator**, I want to pass the domain suffix as **`contoso.com`** or **`@contoso.com`**, so that either convention works without manual editing.
3. As an **identity operator**, I want optional CSV **UserPrincipalName** to override nickname+domain composition, so that exceptions are representable in data.
4. As an **identity operator**, I want CSV **UserPrincipalName** to still participate in collision suffixing when that UPN is taken, so that explicit UPNs are de-duplicated in bulk runs.
5. As an **identity operator**, I want a taken base UPN to try **`jane.doe2`**, **`jane.doe3`**, etc., so that collisions do not stop the batch on the first duplicate.
6. As an **identity operator**, I want the first collision suffix to be **`2`** (not **`1`**), so that numbering matches common directory conventions.
7. As an **identity operator**, I want collision suffix digits appended to the **end of the local part** with no extra separator, so that **`jane.doe`** becomes **`jane.doe2`**, not **`jane2.doe`**.
8. As an **identity operator**, I want a configurable cap on how many UPN candidates are tried per row (default **10**), so that runaway loops cannot occur.
9. As an **identity operator**, I want the row to **fail** with a clear line number when no free UPN exists within the cap, so that I can fix data or raise the cap deliberately.
10. As an **identity operator**, I want CSV **UserPrincipalName** domains to match the configured suffix (case-insensitive), so that I cannot accidentally provision into the wrong domain.
11. As an **identity operator**, I want malformed CSV **UserPrincipalName** values (missing **`@`**, empty local part, multiple **`@`**) to fail that row with a clear line number, so that bad data is caught before **apply**.
12. As an **identity operator**, I want returned UPNs in canonical **lowercase**, so that exists checks and logs are consistent.
13. As an **identity operator**, I want the nickname-built local part to be exactly Task 4’s **MailNickname**, so that **mailNickname** and UPN local part stay aligned without re-normalization drift.
14. As a **contributor**, I want **`Get-DerivedUserPrincipalName`** exported from **BulkIdentityManagement**, so that orchestration and tests share one entry point.
15. As a **contributor**, I want **`-UpnExists`** as a mandatory **ScriptBlock**, so that **Pester** can stub directory state without **Microsoft Graph**.
16. As a **contributor**, I want **`-UpnExists`** to receive the full canonical UPN string on each probe, so that stubs match apply-time gateway behavior.
17. As a **contributor**, I want **`AttemptCount`** on success, so that dry-run and debugging can show how many probes were needed without **ShowIdentifiers**.
18. As a **contributor**, I want **`Get-DerivedUserPrincipalName`** to accept **mapped provisioning identity** from **`Get-MappedProvisioningIdentity`**, so that the pipeline is import → map → derive UPN per row.
19. As a **contributor**, I want the input **provisioning row** and mapped object left unchanged, so that **Department** and audit fields remain available to later tasks.
20. As a **contributor**, I want row-level derivation errors as **`InvalidOperationException`** with **SourceLineNumber**, so that orchestrators map to **row outcome** **failed** consistently with Task 4.
21. As a **contributor**, I want **`-UpnExists`** script block throws to propagate unchanged, so that Graph/transient failures are handled in the apply layer, not mislabeled as CSV errors.
22. As a **contributor**, I want **Pester** tests for suffix progression, CSV override, domain mismatch, cap exceeded, and invalid CSV UPN shape, so that **CI validation gates** protect behavior offline.
23. As a **security reviewer**, I want Task 5 to perform no **Apply** or Graph operations, so that default CI needs no tenant credentials.
24. As a **maintainer**, I want UPN parsing, suffix generation, and domain normalization in private helpers, so that the public surface stays narrow.
25. As a **developer**, I want collision driven by **UPN existence only**, so that Task 5 stays testable and mailNickname-only conflicts are handled at user create time later.
26. As an **identity operator**, I want **`custom.alias@contoso.com`** taken to try **`custom.alias2@contoso.com`**, so that CSV overrides behave like derived UPNs under collision.
27. As a **contributor**, I want **MaximumUpnCandidates** validated between **1** and **99**, so that misconfiguration fails fast at the parameter boundary.
28. As a **maintainer**, I want Task 5 acceptance criteria from the implementation plan satisfied, so that Task 5 can be marked complete without starting Task 6.
29. As a **stakeholder**, I want in-batch duplicate UPNs (two rows deriving the same base) handled by the orchestrator later, not inside per-row derivation, so that Task 5 remains a pure single-row module.
30. As a **stakeholder**, I want this PRD published with **`ready-for-agent`**, so that implementation can proceed without re-grilling decisions already captured in **CONTEXT**.

## Implementation Decisions

### Modules to build or modify

| Module / unit | Role | Public surface |
|---------------|------|----------------|
| **Identity derivation** | Deep module: compose/parse UPN, collision loop, domain validation | **`Get-DerivedUserPrincipalName`** |
| **Tenant domain suffix normalization** (private) | Accept **`contoso.com`** or **`@contoso.com`**; emit canonical domain without leading **`@`** | Not exported |
| **UPN candidate builder** (private) | Base local part from CSV UPN or **MailNickname**; append suffix digits **`2`…`N`**; compose **`local@domain`**; lowercase full UPN | Not exported |
| **CSV UPN validation** (private) | Exactly one **`@`**; non-empty local part and domain after trim; domain equals normalized suffix (case-insensitive) | Not exported |
| **BulkIdentityManagement** (host) | Export public function; dot-source private scripts; no Graph calls | Add **`Get-DerivedUserPrincipalName`** to **FunctionsToExport** |

**Processing order inside `Get-DerivedUserPrincipalName`:**

1. Validate mandatory parameters (**ProvisioningRow**, **MappedProvisioningIdentity**, **TenantDomainSuffix**, **UpnExists** script block); validate **MaximumUpnCandidates** in range **1**–**99** (default **10**).
2. Normalize **TenantDomainSuffix** (strip leading **`@`**).
3. Determine base local part: if row has **UserPrincipalName**, parse/validate CSV UPN and verify domain matches suffix; else use **MappedProvisioningIdentity.MailNickname** verbatim (no re-normalization).
4. Loop: build candidate UPN (canonical lowercase); invoke **`-UpnExists`**; on **false**, return success object; on **true**, advance suffix (**2**, **3**, …) until **MaximumUpnCandidates** exhausted.
5. On cap exceeded or validation failure, throw **`System.InvalidOperationException`** including **SourceLineNumber** from the row (or mapped identity, must match row).

**Does not:** call **`Get-MappedProvisioningIdentity`**; track in-batch claimed UPNs; import **Microsoft.Graph**.

### **`Get-DerivedUserPrincipalName` contract**

| Parameter | Required | Notes |
|-----------|----------|-------|
| **ProvisioningRow** | Yes | From **`Import-ProvisioningCsv`**; supplies optional **UserPrincipalName**, **SourceLineNumber** |
| **MappedProvisioningIdentity** | Yes | From **`Get-MappedProvisioningIdentity`**; supplies **MailNickname** when row has no UPN |
| **TenantDomainSuffix** | Yes | Non-secret verified domain; **`contoso.com`** or **`@contoso.com`** |
| **UpnExists** | Yes | **ScriptBlock**; param: full UPN **string**; return **bool** (**true** = taken). No default. Throws propagate. |
| **MaximumUpnCandidates** | No | Default **10**; min **1**, max **99** — counts base attempt plus suffixed forms |

**Success output (PSCustomObject):**

| Property | Notes |
|----------|-------|
| **UserPrincipalName** | Canonical **lowercase** full address |
| **SourceLineNumber** | From **provisioning row** |
| **AttemptCount** | Number of **`-UpnExists`** invocations, **including** the successful probe |

**Failure:** **`System.InvalidOperationException`** for invalid CSV UPN, domain mismatch, cap exceeded; message cites physical **SourceLineNumber**.

### **UPN composition rules**

- **No CSV UPN:** **`{MappedProvisioningIdentity.MailNickname}@{normalizedDomain}`** as first candidate.
- **CSV UPN present:** use trimmed value as first candidate (then lowercase entire UPN for output); do not compose from nickname+suffix.
- **Collision:** append **`2`**, **`3`**, … to **end of local part** (no separator); re-compose with same domain.
- **Exists gate:** **UPN only** via **`-UpnExists`**; no separate **MailNickname** collision loop in Task 5.

### **Examples (nickname-built, domain `contoso.com`, stub exists only for base)**

| Mapped MailNickname | UpnExists stub | Result UPN | AttemptCount |
|---------------------|----------------|------------|--------------|
| jane.doe | base taken, `jane.doe2` free | jane.doe2@contoso.com | 2 |
| ada.lovelace | none taken | ada.lovelace@contoso.com | 1 |

### **Examples (CSV UPN override)**

| Row UserPrincipalName | Suffix param | UpnExists | Result / failure |
|----------------------|--------------|-----------|------------------|
| Custom.Alias@contoso.com | contoso.com | base taken | custom.alias2@contoso.com |
| ada@fabrikam.com | contoso.com | — | **fail** domain mismatch |
| not-an-email | contoso.com | — | **fail** invalid shape |

### **Dependencies and isolation**

- **Depends on** Task 3 **provisioning row** and Task 4 **mapped provisioning identity** shapes.
- **Does not** import or call **Microsoft.Graph** in Task 5 code or Task 5 **Pester** tests.
- **Does not** implement **IT department rule**, **Graph gateway**, auth, orchestration, **row outcome** reporting, entry script, or in-batch duplicate tracking (**Tasks 6–17**).

### **Documentation alignment**

- **CONTEXT.md** is normative; grill session resolutions for Task 5 are merged there (**Identity derivation**, **AttemptCount**, API shape).
- Parent **IMPLEMENTATION-PLAN** Task 5 checkboxes updated when acceptance criteria are met.

### **No ADR required**

Collision suffix placement and CSV override behavior are specified in **CONTEXT.md**; add an ADR only if implementation discovers a hard-to-reverse Entra API constraint not covered by the glossary.

## Testing Decisions

### What makes a good test

- Assert **observable behavior** of **`Get-DerivedUserPrincipalName`**: **UserPrincipalName**, **AttemptCount**, throw vs success, and stable substrings in exception messages (**physical line** / cap exceeded).
- Use **ScriptBlock** stubs for **`-UpnExists`** (e.g. hashtable of taken UPNs or scripted sequence of **true**/**false**).
- Build **provisioning row** and **mapped provisioning identity** as **PSCustomObject** mirrors of Task 3/4 outputs; chain import → map → derive in a few smoke tests optional.
- Avoid asserting private helper names unless they become deliberate stable API (they should not).

### Modules to test

| Module | Test? |
|--------|-------|
| **`Get-DerivedUserPrincipalName`** | **Yes** — primary **Pester** suite for Task 5 |
| **BulkIdentityManagement** manifest | **Yes** — **FunctionsToExport** includes **`Get-DerivedUserPrincipalName`** after implementation |
| Private UPN/suffix/domain helpers | **No** direct tests; covered via public command |

### Recommended test scenarios (non-exhaustive)

- Nickname-built: free on first probe → **AttemptCount** 1, lowercase UPN.
- Nickname-built: base and **2** taken, **3** free → **jane.doe3@contoso.com**, **AttemptCount** 3.
- Suffix parameter **`@contoso.com`** normalizes same as **`contoso.com`**.
- CSV **UserPrincipalName** override: composition skipped; collision on local part.
- CSV domain mismatch → **InvalidOperationException** with line number.
- Invalid CSV UPN (no **`@`**, double **`@`**, empty local part) → throw.
- Cap exceeded: stub all candidates taken → throw mentions cap and line.
- **MaximumUpnCandidates** **1**: only base tried.
- **UpnExists** throws → exception propagates (not wrapped as row validation).
- Input row and mapped identity not mutated after call.
- Optional: **`Import-ProvisioningCsv`** → **`Get-MappedProvisioningIdentity`** → **`Get-DerivedUserPrincipalName`** on fixture with optional UPN column.

### Prior art

- Task 4 **Pester**: **`Task4.*.Tests.ps1`**, **`Should -Throw`**, module import **BeforeAll**, mapped identity fixtures.
- Task 3 **Pester**: row objects with optional **UserPrincipalName** (e.g. **`ada@contoso.com`**).
- Task 4 closure tests: guard against Task 6+ symbols in Task 5 delivery.

### Manual verification (implementation plan)

- In **pwsh**, map one row, derive UPN with **`UpnExists { $false }`**, inspect lowercase UPN and **AttemptCount**.
- Repeat with stub returning **true** for base only; confirm **`…2@domain`**.

## Out of Scope

- **IT department rule** (**Task 6**).
- **Graph gateway**, real/fake Graph, **graph transient policy** HTTP retries, authentication (**Tasks 7–10**).
- **Orchestrator**, **row outcome** reporting, in-batch “UPN claimed this run” tracking, **dry run** / **apply** wiring (**Tasks 11–13**).
- Entry script parameters, default CI workflow changes beyond new tests (**Tasks 13–14**).
- Sample CSV / runbook updates unless a single README cross-link is needed (**Task 16**).
- **MailNickname**-only directory uniqueness loop separate from UPN.
- Calling **`Get-MappedProvisioningIdentity`** inside **`Get-DerivedUserPrincipalName`**.
- Live tenant **Microsoft Graph** exists checks in Task 5 **Pester** or default CI.

## Further Notes

- **Normative alignment:** If this PRD disagrees with **CONTEXT.md**, **CONTEXT** wins.
- **Task lock:** Implement **Task 5** only; do not start **Task 6** or later in the same delivery unless explicitly expanded.
- **Apply vs derivation:** When the **orchestrator** later finds an **existing** UPN at apply time, **re-run behavior** is **skip** by default—that is separate from derivation’s job to pick a **free** candidate before create.
- **Gateway handoff:** Task 10+ should wrap Graph user lookup as **`-UpnExists`** at apply time; derivation stays pure.
- **Module naming:** **BulkIdentityManagement** per **CONTEXT**.
