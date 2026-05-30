# Implementation Plan: Bulk Identity Management (v1)

**Source PRD:** [PRD.md](PRD.md). **Normative contract:** [CONTEXT.md](../../CONTEXT.md). **Design references:** [HLD.md](HLD.md), [SEC.md](SEC.md), [IDD.md](IDD.md).

## Overview

Implement PowerShell 7 **bulk provisioning** as a small set of **deep modules** (CSV contract, pure identity/name logic, IT rule, Graph gateway, auth session, orchestration, reporting) with **Pester** coverage for all deterministic behavior and **default CI** that runs **PSScriptAnalyzer** and **Pester** without calling **Microsoft Graph**. Deliver an operator-facing entry point, pinned **Microsoft.Graph** dependencies, documentation (**README** opens with **CONTEXT** first), and an optional **GitHub Actions** manual workflow pattern aligned with **SEC**—without requiring Terraform for core workstation **apply**.

## Architecture Decisions

- **Layout:** PowerShell **module(s)** under a single repository-owned root (e.g. `src/Modules/<ModuleName>/`) plus **Pester** tests under `tests/`; manifest pins **Microsoft.Graph** and related modules per **CONTEXT** (no floating `Latest`).
- **Graph access:** Prefer **Microsoft.Graph** PowerShell modules targeting **`v1.0`** only; centralize HTTP/cmdlet calls and **graph transient policy** in one **Graph gateway** implementation behind a **narrow interface** consumed by orchestration.
- **Test doubles:** Orchestration and dry-run paths are verified with an **in-memory / scripted fake** gateway so **CI** never needs tenant credentials.
- **Integration:** Live-tenant verification is a **manual or lab-pipeline** checklist, not a default PR gate.

## Dependency Graph (Implementation Order)

```
Pinned modules + repo hygiene (Task 1)
    │
    ├── README + operator docs skeleton (Task 2)
    │
    ├── CSV contract module (Task 3)
    │       │
    │       └── Name mapping + nickname normalization (Task 4)
    │               │
    │               └── UPN build + collision policy with injectable exists-check (Task 5)
    │
    ├── IT department rule (Task 6)
    │
    ├── Graph gateway contract (Task 7)
    │       │
    │       ├── Fake graph gateway (Task 8)
    │       ├── Auth session — cert client (Task 9)
    │       └── Real graph gateway + retries (Task 10)
    │
    ├── Row outcomes + output hygiene (Task 11)
    │       │
    │       └── Orchestrator — dry run + apply (fake gateway) (Task 12)
    │
    ├── Entry script wiring real gateway (Task 13)
    │
    ├── Default CI — PSScriptAnalyzer + Pester + install from manifest (Task 14)
    │
    ├── Optional manual workflow template + doc (Task 15)
    │
    └── Sample CSV + runbook + lab checklist (Tasks 16–17)
```

Foundation tasks (1–3) unblock all logic; **Tasks 4–6** can proceed in parallel after **Task 3** once CSV row shape is stable. **Tasks 7–8** before **Task 12**; **Task 9** before **Task 10** and **Task 13**; **Task 11** before **Task 12**.

---

## Task List

### Phase 1: Foundation

## Task 1: Repository scaffold and pinned module manifest

**Description:** Add a minimal PowerShell project layout: module folder placeholder, `requirements.psd1` (or equivalent) with **exact pinned** **Microsoft.Graph** (and related) versions, `.gitignore` entries for secrets, certificates, `*.tfvars`, local config, and transcripts that might contain sensitive **apply** output.

**Acceptance criteria:**
- [x] A repository-owned manifest lists **exact** module versions (no floating **Latest**).
- [x] `.gitignore` excludes common secret and credential paths documented in **SEC** / **CONTEXT**.
- [x] `pwsh` is documented as the supported runtime (**7.2+**, **7.4+** preferred).

**Verification:**
- [x] Manual: `Test-ModuleManifest` (or equivalent) succeeds on the manifest if a module manifest is present.
- [x] Manual: Confirm no real tenant IDs or secrets were added to tracked files.

**Dependencies:** None

**Files likely touched:**
- `requirements.psd1` (or `src/Modules/<Name>/<Name>.psd1` with `RequiredModules`)
- `.gitignore`
- Optional: `src/Modules/<Name>/` placeholder

**Estimated scope:** Small (1–2 files)

---

## Task 2: README aligned with documentation authority

**Description:** Add **README** that points to **CONTEXT.md** first, summarizes **apply path** vs **CI scope**, states **dry-run before mutating apply**, and links **HLD**, **IDD**, **SEC**, **PRD**, and informal **init-project** as background. No committed secrets or real tenant identifiers.

**Acceptance criteria:**
- [x] **README** opens with a pointer to **CONTEXT.md** as normative. — README now starts with **`CONTEXT.md`** as the normative glossary and behavioral contract.
- [x] **CI validation gates** and **no Graph in default CI** are stated explicitly. — README documents validate-only **PSScriptAnalyzer** / **Pester** gates and says default CI does not call **Microsoft Graph**.
- [x] Certificate material **outside repo** is stated; **client secret** not default. — README states certificate/private-key material stays outside the repository and client secret is not the default path.

**Verification:**
- [x] Manual: README renders correctly; links resolve relative to repo root. — README artifact verification passed for Markdown structure, root-relative links, and secret/unsupported-command hygiene.

**Dependencies:** Task 1 (optional overlap; can start in parallel once paths known)

**Files likely touched:**
- `README.md`

**Estimated scope:** Small

---

### Phase 2: Deterministic core (no Graph)

## Task 3: Provisioning CSV contract module

**Description:** Implement parsing and validation for **comma-separated**, **UTF-8** input with optional **UTF-8 BOM**, header row, required columns **FirstName**, **LastName**, **Department**; fail with clear errors when missing or non-parseable. Emit structured **provisioning row** objects for downstream modules.

**Acceptance criteria:**
- [x] Required headers validated before row iteration. — Header map validated before row materialization in `Import-ProvisioningCsv`.
- [x] UTF-8 with and without BOM reads correctly. — `Task3.ProvisioningCsv.Success.Tests.ps1` (BOM and no-BOM fixtures).
- [x] Malformed files produce clear, actionable errors (no partial silent apply). — `Task3.ProvisioningCsv.Failure.Tests.ps1`; fail-closed with no pipeline output on error.

**Verification:**
- [x] Tests pass: `Invoke-Pester` (or `pwsh -c "Invoke-Pester 'tests/...'"`) scoped to CSV contract tests. — `tests/Task3.*.Tests.ps1` (**117** tests).
- [x] Manual: Run validator against a tiny good CSV and a bad CSV. — `Task3.SubTaskJ.Closure.Tests.ps1` smoke scenarios.

**Dependencies:** Task 1

**Files likely touched:**
- `src/Modules/<Name>/Public/` or equivalent — CSV functions
- `tests/CsvContract.Tests.ps1` (example path)

**Estimated scope:** Small–Medium (2–4 files)

---

## Task 4: Name mapping and mail nickname normalization

**Description:** Implement **name mapping** from **FirstName** / **LastName** (trim, collapse internal spaces) to **givenName**, **surname**, **displayName**. Implement default **MailNickname** normalization (lowercase, strip accents, safe characters per **CONTEXT** / PRD). Optional CSV overrides for **MailNickname** / **UserPrincipalName** pass through when present (v1 minimal sample may omit **GivenName**/**Surname**/**DisplayName** overrides—document reserved columns).

**Acceptance criteria:**
- [x] **givenName**, **surname**, **displayName** match **CONTEXT** rules for default columns. — `Get-MappedProvisioningIdentity` + `Task4.NameMapping.Tests.ps1`.
- [x] Normalization covers documented edge cases (accents, spaces) with Pester examples. — `Task4.MailNickname.Tests.ps1` and mapping diacritic cases.
- [x] Optional **GivenName** / **Surname** / **DisplayName** overrides active in v1; v1 sample CSV stays minimal (core columns only). — **CONTEXT** + override tests; no sample CSV change in Task 4.

**Verification:**
- [x] Tests pass: Pester for name mapping and nickname cases. — `tests/Task4*.Tests.ps1` (**34** tests, includes `Task4.Mapping.Security.Tests.ps1`).

**Dependencies:** Task 3 (row shape) — or define shared **row type** in Task 3 so Task 4 can parallelize after interface is frozen.

**Files likely touched:**
- `src/Modules/<Name>/Private/` or `Public/` — name/nickname functions
- `tests/NameMapping.Tests.ps1`

**Estimated scope:** Small

---

## Task 5: UPN composition and collision suffix policy (pure + injectable)

**Description:** Build proposed **UserPrincipalName** from row + configured **tenant domain suffix** (non-secret parameter). Implement numeric suffix strategy when an injectable **Test-UpnExists** (or equivalent) returns true, up to a documented cap; when cap exceeded, surface a failure suitable for **row outcome**.

**Acceptance criteria:**
- [x] Full UPN from CSV overrides nickname+suffix path when **UserPrincipalName** column present. — `Get-DerivedUserPrincipalName` + `Task5.UpnCsvOverride.Tests.ps1`.
- [x] Collision loop uses injectable predicate (no live Graph in unit tests). — **`-UpnExists`** script block; `Task5.UpnCollision.Tests.ps1`.
- [x] Bounded attempts: aligns with **graph transient policy** spirit for apply-time (unit test the bound). — **`-MaximumUpnCandidates`**; `Task5.UpnCollisionLimits.Tests.ps1`.

**Verification:**
- [x] Tests pass: Pester for suffix progression with stubbed exists-check. — `tests/Task5*.Tests.ps1` (**31** tests, includes security suite).

**Dependencies:** Task 4

**Files likely touched:**
- `src/Modules/<Name>/` — identity derivation
- `tests/IdentityDerivation.Tests.ps1`

**Estimated scope:** Small

---

## Task 6: IT department rule predicate

**Description:** Implement case-insensitive match of **Department** to configurable target (default **`IT`**). Single function or cmdlet used by orchestrator and tests.

**Acceptance criteria:**
- [x] Default **`IT`** match is case-insensitive. — `Test-ProvisioningDepartmentMatch` with `OrdinalIgnoreCase`; `Task6.DepartmentMatch.Tests.ps1`.
- [x] Configurable target string supported via parameter for tests and operators. — `-Target` parameter with default `'IT'`; custom target tests.

**Verification:**
- [x] Tests pass: Pester for rule edge cases (`it`, `IT ` trimmed?, etc. — align with **CONTEXT**: **Department** trimmed on user attribute; clarify trim on rule input in tests). — `tests/Task6*.Tests.ps1` (**12** department match + closure tests).

**Dependencies:** Task 3

**Files likely touched:**
- `src/Modules/<Name>/` — rule function
- `tests/ItDepartmentRule.Tests.ps1`

**Estimated scope:** XS–Small

---

### Checkpoint: After Tasks 1–6

- [x] `Invoke-Pester` passes for all tests written to date. — Full suite green (Tasks 1–6 and later tasks; no failures).
- [x] No **Microsoft.Graph** import required for Tasks 3–6 tests. — Task 3–6 Pester uses CSV/identity logic only.
- [x] Optional: quick human review of CSV error messages for clarity. — Covered by Task 3 failure tests and closure smoke.

---

### Phase 3: Graph boundary and orchestration (fake gateway)

**Phase status (2026-05-28):** **6 complete** (Tasks 7–12). Full **Pester** suite green without live Graph.

| Task | Focus | Status |
|------|--------|--------|
| **7** | Gateway contract (signatures, docs) | **Complete** |
| **8** | In-memory fake gateway | **Complete** |
| **9** | Certificate auth session | **Complete** |
| **10** | Real gateway + graph transient policy | **Complete** |
| **11** | Row outcomes + output hygiene | **Complete** |
| **12** | Orchestrator (dry run + apply on fake) | **Complete** |

**Note:** Task 10’s [PLAN](tasks/task-10/PLAN-Task-10-Real-Graph-Gateway.md) uses numbered *phases* (1–6) for implementation slices; that is separate from this **Implementation Plan Phase 3** (Tasks 7–12).

**Phase lock [3] completion checklist** (Implementation Plan Phase 3 — Tasks 7–12):

- [x] **Task 7** — Phase 3 lock complete. — `tests/Task7*.Tests.ps1` (**14** tests).
- [x] **Task 8** — Phase 3 lock complete. — `tests/Task8*.Tests.ps1` (**23** tests).
- [x] **Task 9** — Phase 3 lock complete. — `tests/Task9*.Tests.ps1` (**25** tests).
- [x] **Task 10** — Phase 3 lock complete. — `tests/Task10*.Tests.ps1` (**42** tests: retry, helpers, operations, security, Phase 3 + closure).
- [x] **Task 11** — Phase 3 lock complete. — `tests/Task11*.Tests.ps1` (**9** tests: 7 behavior + 2 closure).
- [x] **Task 12** — Phase 3 lock complete. — `tests/Task12*.Tests.ps1` (**8** tests: 6 orchestrator + 2 closure).

---

## Task 7: Graph gateway contract (narrow interface)

**Description:** Define the minimal set of operations the orchestrator needs: e.g. resolve **UPN** existence, create user (member) with required fields, patch limited attributes for **UpdateExisting**, resolve **IT membership group** by **Object ID**, test membership, add member. Use PowerShell patterns appropriate to the repo (private functions in a **Gateway** submodule or a small class). No Microsoft.Graph calls inside this task—signatures and documentation only.

**Acceptance criteria:**
- [x] Orchestrator dependencies are expressible against this contract alone. — `New-FakeProvisioningGraphGateway` stub with six ScriptBlock entries matching orchestrator consumption pattern.
- [x] All operations are documented as **v1.0** Graph semantics. — Contract documented in CONTEXT.md and source docstring; all six ops map to v1.0 Graph calls.

**Verification:**
- [x] Manual: Review interface vs **CONTEXT** (permissions, fields, group resolution by id). — `tests/Task7*.Tests.ps1` (**14** tests: 9 contract + 5 closure).

**Dependencies:** Tasks 4–6 (field names stable)

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Private/Graph/New-FakeProvisioningGraphGateway.ps1`
- `tests/Task7*.Tests.ps1`

**Estimated scope:** Small

---

## Task 8: In-memory / fake graph gateway

**Description:** Implement the Task 7 contract with in-memory dictionaries so Pester can simulate existing users, groups, and members without network.

**Acceptance criteria:**
- [x] Fake supports paths needed for dry-run and apply unit tests (create, skip, update, group add idempotent). — `New-FakeProvisioningGraphGateway -State` with in-memory Users/UpnIndex/Groups/Members; all six ops implemented.
- [x] No network calls. — Pure in-memory dictionaries and HashSets; zero imports of Microsoft.Graph.

**Verification:**
- [x] Tests pass: Pester tests targeting fake only. — `tests/Task8*.Tests.ps1` (**23** tests: 18 behavior + 5 closure).

**Dependencies:** Task 7

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Private/Graph/New-FakeProvisioningGraphGateway.ps1`
- `tests/Task8*.Tests.ps1`

**Estimated scope:** Small

---

## Task 9: Authentication session (certificate client credentials)

**Description:** Encapsulate connecting to Microsoft Graph as the **automation principal** using certificate-based client credentials (thumbprint or cert path parameters). Do not implement **client secret** as default. Integrate with **Microsoft.Graph** session commands per pinned module docs.

**Acceptance criteria:**
- [x] Connect path works with test cert in operator lab (documented separately—not committed). — `Connect-ProvisioningGraph` with Thumbprint and CertificatePath parameter sets; Pester happy-path tests with mocked `Connect-MgGraph`.
- [x] Clear errors when cert or tenant/client parameters invalid. — GUID validation, thumbprint format, file existence/extension, private key check; all throw `InvalidOperationException`.

**Verification:**
- [x] Manual: Connect to a dev tenant with lab app registration (not in CI). — Lab verified 2026-05-28: `Connect-ProvisioningGraph` (thumbprint) to **Bulk ID Manager** app; `Get-MgContext` returned **AppOnly**. Graph API smoke (`Get-MgOrganization`) returned 403 until application permissions are granted (expected pre–Task 10).
- [x] CI: This task’s code is covered by **PSScriptAnalyzer** only unless mocked—no Graph in CI. — `tests/Task9*.Tests.ps1` (**25** tests: 11 behavior + 9 security + 5 closure); all mock `Connect-MgGraph`.

**Dependencies:** Task 1

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Public/Connect-ProvisioningGraph.ps1`
- `tests/Task9*.Tests.ps1`

**Estimated scope:** Small–Medium

---

## Task 10: Real graph gateway + graph transient policy

**Description:** Implement the Task 7 contract using **Microsoft.Graph** **v1.0** cmdlets or REST, including **bounded retries** for **429** / selected **5xx**, honoring **Retry-After** when present. Map Graph exceptions to stable messages for **row outcomes**.

**Progress:** Task 10 complete 2026-05-28 — see [PLAN-Task-10-Real-Graph-Gateway.md](tasks/task-10/PLAN-Task-10-Real-Graph-Gateway.md).

**Acceptance criteria:**
- [x] No **beta** profile by default. — `New-ProvisioningGraphGateway` calls `Select-MgProfile -Name 'v1.0'` at construction; not exported.
- [x] Retries are capped (attempt count and/or cumulative wait). — `Invoke-ProvisioningGraphCommand` (5 attempts, 90s cumulative cap, exponential backoff).
- [x] **IT membership group** resolved by **Object ID** (no display-name-only fuzzy search). — `GetGroupById` / membership ops use `Get-MgGroup -GroupId` and GUID validation.

**Verification:**
- [ ] Manual: Run against lab tenant with small CSV (after Task 13 entry exists, or provisional script). Lab auth verified 2026-05-28; grant `User.ReadWrite.All`, `Group.Read.All`, `GroupMember.ReadWrite.All` before gateway smoke.
- [x] CI (Task 10 complete): All `tests/Task10*.Tests.ps1` green; mocked Graph cmdlets; no live tenant. — **42** tests (2026-05-28). PSScriptAnalyzer **0** on gateway + retry source (closure-checked).

**Dependencies:** Tasks 7, 9

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Private/Graph/New-ProvisioningGraphGateway.ps1`
- `src/Modules/BulkIdentityManagement/Private/Graph/Invoke-ProvisioningGraphGatewayOperations.ps1`
- `src/Modules/BulkIdentityManagement/Private/Graph/Invoke-ProvisioningGraphCommand.ps1`
- `src/Modules/BulkIdentityManagement/Private/Graph/ConvertTo-ProvisioningGraphODataLiteral.ps1`, `ConvertTo-ProvisioningGraphNewUserBody.ps1`, `ConvertTo-ProvisioningGraphPatchBody.ps1`, `New-ProvisioningGraphUserPassword.ps1`, `Test-ProvisioningGraphObjectId.ps1`, `Test-ProvisioningGraphGroupMembership.ps1`, `Get-ProvisioningGraphErrorMetadata.ps1`
- `tests/Task10.RealGateway*.Tests.ps1`, `tests/Task10.Phase3*.Tests.ps1`, `tests/Task10.Closure.Tests.ps1`

**Estimated scope:** Medium

---

## Task 11: Row outcomes, aggregate report, output hygiene

**Description:** Define **row outcome** enum or structured objects (created, skipped, updated, membership ensured, failed). Implement aggregate summary and default console formatting that omits passwords and avoids full **UPN** / object IDs unless **ShowIdentifiers** is enabled.

**Acceptance criteria:**
- [x] Passwords never written to default streams. — `Format-ProvisioningRowOutcomeDisplayLine` redacts credential patterns; tests assert no password material in output.
- [x] **ShowIdentifiers** opt-in documented with README warning. — README **Apply output hygiene** section documents `-ShowIdentifiers` lab-only use.
- [x] Exit code policy: **non-zero** if any row failed (**batch error policy**). — `Get-ProvisioningBatchExitCode` returns **1** when any outcome is **Failed**.

**Verification:**
- [x] Tests pass: Pester on formatting/redaction logic with fixed inputs. — `tests/Task11*.Tests.ps1` (**9** tests).

**Dependencies:** None (can parallelize after Task 3); practically before Task 12

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Private/Reporting/ProvisioningRowOutcome.Constants.ps1`
- `src/Modules/BulkIdentityManagement/Private/Reporting/New-ProvisioningRowOutcome.ps1`
- `src/Modules/BulkIdentityManagement/Private/Reporting/Format-ProvisioningRowOutcomeDisplayLine.ps1`
- `src/Modules/BulkIdentityManagement/Private/Reporting/Get-ProvisioningBatchExitCode.ps1`
- `src/Modules/BulkIdentityManagement/Private/Reporting/Write-ProvisioningAggregateReport.ps1`
- `tests/Task11.RowOutcome.Tests.ps1`, `tests/Task11.Closure.Tests.ps1`

**Estimated scope:** Small

---

## Task 12: Apply orchestrator (dry run + apply) against fake gateway

**Description:** Implement batch loop: for each row, compute identity, dry-run plan line, or mutating path (skip by default if UPN exists; **UpdateExisting** limited fields), then **IT membership ensure** for qualifying rows. Continue on row failure; collect outcomes; set exit code.

**Acceptance criteria:**
- [x] **Dry run** performs no mutating calls on fake (assert call counts / state unchanged). — `Invoke-ProvisioningOrchestrator -DryRun`; `Task12.Orchestrator.Tests.ps1`.
- [x] **Apply** with fake mutates fake state consistent with **CONTEXT** ordering (user resolved before group). — Create/skip/update paths against `New-FakeProvisioningGraphGateway`.
- [x] **IT membership ensure** runs when user creation skipped but row qualifies. — **MembershipEnsured** outcome when existing IT user gains group membership.

**Verification:**
- [x] Tests pass: Pester end-to-end on fake for representative scenarios. — `tests/Task12*.Tests.ps1` (**8** tests).

**Dependencies:** Tasks 3–8, 11

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Private/Orchestration/Invoke-ProvisioningOrchestrator.ps1`
- `tests/Task12.Orchestrator.Tests.ps1`, `tests/Task12.Closure.Tests.ps1`

**Estimated scope:** Medium

---

### Checkpoint: After Tasks 7–12

- [x] Full **Pester** suite green without Graph. — `Invoke-Pester './tests'` green (2026-05-28); includes Task 10 real gateway tests (mocked Graph cmdlets; no live tenant).
- [x] Tasks **7–10** acceptance complete.
- [x] Tasks **11–12** acceptance complete.
- [x] Orchestrator behaviors match **CONTEXT** for skip/update/membership/order. — `Task12.Orchestrator.Tests.ps1`.
- [x] Quick review of **row outcome** vocabulary vs support expectations. — Task 11 status labels align with CONTEXT (Created, Skipped, Updated, MembershipEnsured, Failed).

---

### Phase 4: Entry point and live gateway wiring

**Phase status (2026-05-30):** **Task 13 complete** (operator entry + live gateway wiring). Pester covers wiring with mocked Graph; lab dry run/apply remains manual.

| Task | Focus | Status |
|------|--------|--------|
| **13** | Operator entry script (parameters + wiring) | **Complete** |

**Phase lock [4] completion checklist** (Implementation Plan Phase 4 — Task 13):

- [x] **Task 13** — Phase 4 lock complete. — `tests/Task13*.Tests.ps1` (**13** tests: 5 entry wiring + 5 security + 3 closure).
- [x] **Architecture hygiene** — No loose `Private/*.ps1` at module root; phased subfolders only (`Csv`, `Identity`, `Reporting`, `Graph`, `Orchestration`, `Shared`). Guard: `Task3.SubTaskA.ModuleLayout.Tests.ps1`.

## Task 13: Operator entry script (parameters + wiring)

**Description:** Public entry (script or manifest-exported command) accepting CSV path, tenant/client identifiers, certificate parameters, **IT membership group** id, domain suffix, **WhatIf**/**DryRun**, **UpdateExisting**, optional **usage location**, **ShowIdentifiers**, configurable IT target string. Wire **Task 10** gateway + **Task 9** auth + **Task 12** orchestrator.

**Acceptance criteria:**
- [x] Parameters align with **CONTEXT**; **dry-run before mutating apply** documented in usage. — `Invoke-BulkIdentityProvisioning` help + README apply section; `-DryRun`/`-WhatIf`.
- [x] New users: random password, **forceChangePasswordNextSignIn**, **accountEnabled** true, optional **usageLocation** when parameter supplied. — `New-ProvisioningGraphGateway` / `Get-ProvisioningOrchestratorNewUserProperties` (Task 10/12); entry forwards `-UsageLocation`.

**Verification:**
- [ ] Manual: Dry run and small apply in lab tenant (after app permissions granted).
- [x] PSScriptAnalyzer clean on new scripts. — CI gate; entry sources follow existing suppressions.
- [x] Tests pass: Pester wiring with mocked Connect/Graph gateway. — `tests/Task13.Entry.Tests.ps1`.
- [x] Tests pass: dry-run entry output omits password material (runtime). — `tests/Task13.Entry.Security.Tests.ps1`.

**Dependencies:** Tasks 10–12

**Files likely touched:**
- `src/Modules/BulkIdentityManagement/Public/Invoke-BulkIdentityProvisioning.ps1`
- `src/Scripts/Invoke-BulkIdentityProvisioning.ps1`
- `tests/Task13*.Tests.ps1`
- `README.md` (parameters section)

**Estimated scope:** Medium

---

### Phase 5: CI/CD and optional GitHub apply pattern

## Task 14: Default GitHub Actions CI (validate-only)

**Description:** Workflow using **`pwsh`**: install modules from pinned manifest, **Invoke-Pester**, **PSScriptAnalyzer** with fail on **Error** and **Warning** for `.ps1`/`.psm1`. No secrets; no Graph calls.

**Acceptance criteria:**
- [ ] CI fails on analyzer **Warning** severity per **CONTEXT**.
- [ ] CI installs Graph modules only if needed for import analysis—prefer not loading **Microsoft.Graph** at all during tests if imports can be avoided; if unavoidable, use **no authentication** and no network calls to tenant.

**Verification:**
- [ ] Manual: `act` or push to branch triggers workflow (if runner available).
- [ ] Local: run the same commands as CI in one shell block.

**Dependencies:** Tasks 1, 3–12 (tests must exist)

**Files likely touched:**
- `.github/workflows/ci.yml` (or `validate.yml`)
- Optional: `PSScriptAnalyzerSettings.psd1`

**Estimated scope:** Small–Medium

---

## Task 15: Optional manual tenant workflow template

**Description:** Add a **separate** workflow YAML (or documented snippet) triggered only by **`workflow_dispatch`**, using **`entra-apply`** (or placeholder) **GitHub Environment** name and comments for **required reviewers** and **OIDC** per **SEC**. Document that this path is optional and tenant-mutating; default PR CI remains validate-only.

**Acceptance criteria:**
- [ ] Not triggered on `pull_request` / `push` by default.
- [ ] Documentation references **SEC** OIDC subject format.

**Verification:**
- [ ] Manual: Review workflow triggers in GitHub UI (dry check).

**Dependencies:** Task 14 (pattern consistency)

**Files likely touched:**
- `.github/workflows/apply-dispatch-placeholder.yml`
- `README.md` or `docs/` note

**Estimated scope:** Small

---

### Checkpoint: After Tasks 14–15

- [ ] CI green on representative branch.
- [ ] No tenant mutation from default pipeline.

---

### Phase 6: Samples and lab hardening

## Task 16: Sample CSV and operator runbook

**Description:** Commit a **minimal** sample CSV (core columns only) and extend README (or `docs/runbook.md`) with step-by-step: prerequisites (app permissions, admin consent), group **Object ID**, cert placement, **dry run** command, **apply** command, interpreting outcomes.

**Acceptance criteria:**
- [ ] Sample uses fake names only; no real tenant identifiers.
- [ ] Runbook includes **batch error policy** and exit code semantics.

**Verification:**
- [ ] Manual: Another engineer can follow runbook in a lab tenant.

**Dependencies:** Task 13

**Files likely touched:**
- `samples/provisioning-sample.csv` (example path)
- `README.md` or `docs/runbook.md`

**Estimated scope:** Small

---

## Task 17: Lab integration checklist (non-CI)

**Description:** Add a short checklist document for human verification in a dev tenant: throttling behavior spot-check, **IT membership ensure** idempotency, **UpdateExisting** limited fields, password not in logs. Keeps default CI free of live Graph dependency.

**Acceptance criteria:**
- [ ] Checklist covers **CONTEXT** behaviors not fully asserted in unit tests.

**Verification:**
- [ ] Manual: Complete checklist once in lab.

**Dependencies:** Tasks 10, 13, 16

**Files likely touched:**
- `docs/lab-integration-checklist.md` (example path)

**Estimated scope:** XS–Small

---

### Checkpoint: Complete

- [ ] All tasks’ acceptance criteria satisfied.
- [ ] **CONTEXT** behaviors traceable to tests or documented manual checks.
- [ ] Ready for human code review and (if applicable) **`ready-for-agent`** issue closure criteria.

---

## Parallelization Opportunities

| Parallel track A | Parallel track B | After |
|------------------|-------------------|-------|
| Task 4 (names) | Task 6 (IT rule) | Task 3 complete |
| Task 11 (reporting) | Tasks 4–6 | Task 3 stable row type |
| Task 9 (auth) | Tasks 7–8 | Before Task 10 |

Sequential hard gates: **Task 3** before broad parser consumers; **Task 7 → 8 → 12**; **Task 10 → 13**; **Task 12** before **Task 13**.

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Microsoft.Graph** module cmdlet surface changes on version bump | Medium | Pin exact versions; bump only in intentional PRs; Pester on orchestrator with fake gateway isolates most churn. |
| PSScriptAnalyzer rules differ between local and CI | Low | Commit **PSScriptAnalyzerSettings.psd1**; same `Invoke-ScriptAnalyzer` invocation in CI and README. |
| Live tenant tests accidentally run in CI | High | No secrets in GitHub vars for default workflow; fake gateway tests only; lab checklist is human-only. |
| Collision / nickname rules disagree with operator expectations | Medium | Document examples in README; extensive Pester edge cases; dry-run plan output per row. |
| Throttling still exhausts retry budget on large CSVs | Medium | Document batch sizing; surface **row outcome** with throttling message; optional future batching ADR. |

---

## Open Questions

- **Exact public module name and namespace** (`BulkIdentityProvisioning` vs org prefix)—pick before Task 3 files proliferate.
- **Invoke-RestMethod** vs **Microsoft.Graph** cmdlets for gateway implementation—choose one approach for consistency and document in an ADR if tradeoffs are non-obvious.
- **Where optional `workflow_dispatch` apply** should obtain CSV and secrets (artifact upload vs release)—defer until GitHub automation is required; v1 primary path remains local **apply**.

---

## Human review gate

Per planning skill guidance: a **maintainer should approve this plan** (or request edits) before large implementation spend. Adjust task order if the team prefers **entry script stub** earlier for vertical demos—keep fake gateway tests to preserve **CI** safety.
