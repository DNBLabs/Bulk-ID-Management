# PRD: Bulk Identity Management (v1)

**Normative contract:** [CONTEXT.md](../../CONTEXT.md). **Architecture:** [HLD.md](HLD.md), [IDD.md](IDD.md), [SEC.md](SEC.md). **Background:** [../init-project.txt](../init-project.txt).

**Issue tracker:** When this repository has a GitHub remote, create a tracking issue from this document and apply the triage label **`ready-for-agent`**. This workspace had no `git remote` at PRD authoring time, so the issue was not auto-published.

---

## Problem Statement

Directory administrators and engineers need to **bulk provision** workforce (**member**) users in a Microsoft **Entra tenant** from structured **CSV** input, with predictable **identity derivation**, safe **re-run** behavior, and **IT membership group** handling—without one-off manual clicks per user. They also need **confidence** that automation will not silently corrupt directory data, leak **initial passwords** or identifiers into logs, or mutate the tenant from every **CI** run. Today the repository holds the **normative glossary** and design artifacts but not yet the full **PowerShell 7** implementation, **Pester** coverage, and **GitHub Actions** validation gates described in CONTEXT.

## Solution

Deliver a **PowerShell 7**-based **bulk provisioning** tool that:

1. **Validates** provisioning CSVs locally and in **CI** (required headers, UTF-8 including optional BOM, comma-separated contract) with **no Microsoft Graph** calls in default CI.
2. Supports **dry run** (read-only plan per **provisioning row**) and **apply** modes using the **automation principal** with **certificate-based client credentials** for the primary **apply path**; optional **GitHub Actions** tenant-mutating path only via **`workflow_dispatch`** and a protected **GitHub Environment** (e.g. **`entra-apply`**) with **required reviewers**, using **OIDC** (**CI credential**)—no default **client secret** in repo.
3. Creates **new** users with **cryptographically random** **initial passwords** and **`forceChangePasswordNextSignIn`**, sets **`accountEnabled`** true by default, applies **name mapping** and **`department`**, optionally **usage location** via apply-time parameter, and **idempotently ensures** **IT membership ensure** for rows matching the **IT department rule** against a **pre-created** **IT membership group** resolved by **stable identifier** (prefer **group Object ID**).
4. Uses **Microsoft Graph** **`v1.0`** only, with **bounded retries** for throttling and selected server errors, emits **row outcomes** and **aggregate report**, exits **non-zero** if any row failed (**batch error policy**), and redacts **apply output** by default with an opt-in for identifiers in lab scenarios.

## User Stories

1. As an **identity operator**, I want to **provision many users from a CSV**, so that I avoid repetitive manual creation in the **Entra tenant**.
2. As an **identity operator**, I want the CSV to require **FirstName**, **LastName**, and **Department** columns, so that every **provisioning row** has a clear minimum contract.
3. As an **identity operator**, I want the tool to accept **UTF-8** files with an optional **UTF-8 BOM**, so that files exported from common editors work without manual re-encoding.
4. As an **identity operator**, I want validation to **fail fast with a clear error** if required headers are missing, so that I never start an **apply** against a malformed file.
5. As an **identity operator**, I want a **dry run** mode (**`-WhatIf`** / **`-DryRun`**) that prints a **per-row plan** without creating users or changing groups, so that I can review impact before mutating the directory.
6. As an **identity operator**, I want documentation to state **dry-run before mutating apply**, so that my team follows a safe operational habit.
7. As an **identity operator**, I want **apply** to connect as the **automation principal** using **certificate-based client credentials**, so that I do not rely on a **client secret** in the repository.
8. As a **security reviewer**, I want **private keys and certificates outside the repository**, so that credential material is not committed to git.
9. As an **identity operator**, I want to pass **tenant ID**, **client ID**, **certificate thumbprint** or path via parameters or non-committed config, so that I can run **apply** from a secure workstation.
10. As an **identity operator**, I want **UserPrincipalName** built from normalized **MailNickname** plus a **tenant domain suffix** from config, so that UPNs are consistent and the domain suffix is **not a secret** stored in the repo incorrectly.
11. As an **identity operator**, I want optional CSV columns **MailNickname** and **UserPrincipalName** to **override** defaults when present, so that exceptions are representable in data.
12. As an **identity operator**, I want **collision handling** that appends a numeric suffix when a nickname or UPN is taken, so that **bulk provisioning** does not fail on the first duplicate without strategy.
13. As an **identity operator**, I want **re-run behavior** to **skip** creation when the **UserPrincipalName** already exists, so that re-execution is **idempotent** by default.
14. As an **identity operator**, I want an explicit **`-UpdateExisting`** (or equivalent) flag that updates only **`department`**, **`givenName`**, **`surname`**, **`displayName`** per **name mapping**, so that limited corrections are possible without silent broad attribute drift.
15. As an **identity operator**, I want **givenName**, **surname**, and **displayName** derived from **FirstName** and **LastName** with trimming and collapsed spaces, so that directory display fields look professional.
16. As an **identity operator**, I want **Department** persisted to the Entra **`department`** attribute, so that HR or access reviews see correct department metadata.
17. As an **identity operator**, I want the **IT department rule** to match **Department** to a configured value (default **`IT`**) **case-insensitively**, so that minor casing differences do not break automation.
18. As an **identity operator**, I want users matching the **IT department rule** to be **added** to the **IT membership group** if missing, so that access packages tied to that group apply automatically.
19. As an **identity operator**, I want **IT membership ensure** to run even when user creation was **skipped** for an existing UPN, so that returning employees get group membership corrected on **apply**.
20. As a **directory administrator**, I want the **IT membership group** to be **pre-created** and referenced by **stable identifier** (prefer **Object ID**), so that automation does not create or rename security groups in v1.
21. As an **identity operator**, I do **not** need automation to **remove** users from the IT group when department changes, so that v1 scope stays bounded (explicit **out of scope**).
22. As an **identity operator**, I want each **new** user to receive a **cryptographically random** password meeting tenant policy, with **force change at next sign-in**, so that first login is forced secure.
23. As a **security reviewer**, I want **passwords** never written to repo files, default logs, or **CI artifacts**, so that we do not leak credentials.
24. As an **identity operator**, I want default **apply** output to avoid full **UPN**s and **object IDs**, so that transcripts are safer to share; I want an opt-in flag (e.g. **`-ShowIdentifiers`**) for lab debugging with README warning.
25. As an **identity operator**, I want optional **usage location** set for **each newly created user** when an apply-time parameter is provided, so that license assignment policies can apply later without this tool assigning **licenses** itself.
26. As a **compliance reviewer**, I want **license assignment** explicitly **out of scope for v1**, so that licensing remains a separate controlled process.
27. As an **identity operator**, I want **new** users created with **`accountEnabled` = true** by default, so that accounts are ready for first sign-in after password change.
28. As an **identity operator**, if one **provisioning row** fails, I want processing to **continue** for remaining rows, so that a single bad row does not block the entire batch.
29. As an **identity operator**, I want an **aggregate report** of **row outcomes** with human-readable failure reasons, so that I can fix data and re-run efficiently.
30. As an **identity operator**, I want the process exit code to be **non-zero** if **any** row failed, so that CI or orchestrators can detect partial failure.
31. As an **SRE**, I want Graph calls to **retry** on **429** and selected **5xx** with **exponential backoff** and respect for **`Retry-After`**, so that throttling does not fail entire batches unnecessarily.
32. As an **SRE**, I want retries to be **bounded** with a maximum attempt or wait budget per logical operation, so that a stuck tenant does not cause infinite loops.
33. As a **contributor**, I want **default CI** to run **PSScriptAnalyzer** on **`.ps1`** / **`.psm1`** and fail on **Error** and **Warning**, so that script quality stays high.
34. As a **contributor**, I want **Pester** tests for **deterministic** logic (CSV contract, **IT department rule**, **identity derivation** edge cases), so that refactors do not break provisioning rules.
35. As a **security reviewer**, I want **default CI** to **not** call **Microsoft Graph**, so that PR checks never depend on tenant connectivity or credentials.
36. As a **platform engineer**, I want **Microsoft.Graph** module versions **pinned** in a repository-owned manifest, so that CI and local runs are reproducible and upgrades are reviewable PRs.
37. As a **contributor**, I want the documented baseline to be **PowerShell 7.2+** (**7.4+** preferred) via **`pwsh`**, so that we do not support **Windows PowerShell 5.1** in v1.
38. As a **platform engineer**, I want **GitHub Actions** to use **OIDC federation** to the **automation principal** when CI needs Azure AD tokens for non-mutating scenarios, so that there is no long-lived **client secret** in the repo for **CI credential**.
39. As a **security reviewer**, I want any optional tenant-mutating workflow to be **`workflow_dispatch`** only and bound to a **GitHub Environment** with **required reviewers**, so that directory changes require explicit human approval.
40. As a **directory administrator**, I want Graph permissions limited to **`User.ReadWrite.All`**, **`Group.Read.All`**, **`GroupMember.ReadWrite.All`** (application, admin-consented), so that blast radius stays smaller than **`Directory.ReadWrite.All`**.
41. As a **directory administrator**, I want all Graph requests to use the **`v1.0`** surface, so that we avoid unsupported **beta** behavior in production automation.
42. As an **identity operator**, I want only **member** (**workforce**) users in scope, so that **Guest** / B2B flows are not mixed into the same CSV in v1.
43. As a **new maintainer**, I want the **README** to point to **CONTEXT.md** first, so that I understand **normative** behavior before reading informal briefs.
44. As a **security reviewer**, I want design docs (**HLD**, **IDD**, **SEC**) reflected in implementation choices (OIDC subjects, output hygiene, no secrets in repo), so that architecture and code align.
45. As an **identity operator**, I want optional columns for **GivenName**, **Surname**, **DisplayName** reserved for a **future** release without changing the v1 minimal sample shape, so that the roadmap is clear.
46. As an **identity operator**, I want per-row **usage location** via CSV reserved for **future** work, so that v1 stays simple while extensibility is documented in CONTEXT.
47. As a **support engineer**, I want **row outcomes** to distinguish created, skipped, updated (when opted in), membership ensured, and failed states, so that tickets map cleanly to automation behavior.
48. As an **identity operator**, I want **strict fail-fast** for the whole batch to be **not** the default, so that behavior matches CONTEXT; a future **stop on first error** flag may exist later.
49. As a **tenant administrator**, I want **group resolution** to avoid **fuzzy display-name search alone** as the canonical method, so that the wrong group is never targeted.
50. As a **developer**, I want a small **deep module** boundary for **CSV validation and row materialization**, so that tests can cover parsing without Graph.
51. As a **developer**, I want a **deep module** boundary for **identity derivation** (normalization, nickname, suffix rules) separate from Graph HTTP calls, so that Pester stays fast and deterministic.
52. As a **developer**, I want a **Graph invocation layer** that centralizes **v1.0** paths, retry policy, and error translation to **row outcomes**, so that orchestration stays thin and consistent.
53. As an **operator** integrating with IaC, I want the **automation principal** and federated credentials describable in **IDD** / **SEC** without this PRD hardcoding subscription IDs, so that governance stays portable.

## Implementation Decisions

- **Modular boundaries (deep modules):**
  - **Provisioning CSV contract:** Single entry surface that validates headers (**FirstName**, **LastName**, **Department**), handles **UTF-8 BOM**, parses comma-separated rows, and yields structured **provisioning row** objects or typed errors. Hides encoding and delimiter edge cases from callers.
  - **Name mapping and identity derivation:** Pure functions (or a small class) for trimming, collapsing spaces, transliteration/normalization rules for **MailNickname**, default UPN composition from nickname + configured domain suffix, and numeric suffix policy for collisions. Graph existence checks for collisions belong in the apply layer behind an interface so unit tests can fake responses.
  - **IT department rule:** Isolated predicate: case-insensitive compare of **Department** to configured target (default **`IT`**).
  - **Graph apply orchestration:** Reads rows, coordinates dry vs mutating paths, sequences user create/skip/update, then **IT membership ensure**, collects **row outcomes**, enforces **batch error policy** and exit code. Does not embed CSV parsing or pure derivation logic.
  - **Graph gateway:** Wraps **Microsoft.Graph** PowerShell (or REST) calls for **v1.0** only; implements **graph transient policy** (retry budget, backoff, **Retry-After**); maps failures to stable error codes/messages for **row outcomes**.
  - **Authentication session:** Encapsulates connecting to Graph as the **automation principal** via certificate-based client credentials; no default client-secret path; no mixing delegated and application models in v1.
  - **Output and reporting:** Formats operational summaries with **apply output hygiene** defaults and **ShowIdentifiers** opt-in; never writes passwords to default streams; supports aggregate summary object for testing.

- **CI/CD:** Default workflow runs **`pwsh`**, **PSScriptAnalyzer** (fail **Error** + **Warning**), **Pester** without Graph. Optional separate workflow for **`workflow_dispatch`** only, **`entra-apply`** environment, **required reviewers**; OIDC per **SEC** subject binding. Terraform / IaC remains governed by **IDD** and is not required for core CSV apply on a workstation.

- **Permissions model:** Application permissions exactly as CONTEXT; admin consent is a prerequisite documented for operators, not bypassed in code.

- **Idempotency:** Default skip on existing UPN; **UpdateExisting** limited to documented attributes only.

- **Password handling:** Generate per new user; surface only through secure ephemeral channels; document sensitivity of **apply** transcripts.

## Testing Decisions

- **Good tests** assert **observable contracts**: parsed CSV shapes, validation failures for bad headers or encoding, **IT department rule** outcomes, **name mapping** and nickname normalization edge cases, collision suffix selection given **stubbed** “exists” responses, and orchestration behavior (dry run emits plan lines; mutating path calls mocked gateway methods in order). Tests avoid asserting internal private function names unless they are the stable module API.

- **Modules to test first:** **Provisioning CSV contract**, **identity derivation** (pure), **IT department rule**, and **apply orchestration** with a fake **Graph gateway** (no live Graph in CI).

- **Prior art:** Repository currently has design markdown and CONTEXT only; once **Pester** tests exist, they become the reference for deterministic coverage. **PSScriptAnalyzer** settings should be committed so local and CI behavior match.

## Out of Scope

Per **CONTEXT.md** (non-exhaustive): **License assignment**; **Guest** / B2B invitation flows in the same CSV; **Directory.ReadWrite.All`** as a default permission; **beta** Graph endpoints; **Windows PowerShell 5.1**; creating the **IT membership group** in automation v1; removing users from the IT group when department changes; **delegated** / device-code auth for v1; **strict fail-fast** batch mode by default; **StopOnFirstError** in v1; floating **latest** Graph modules; **Microsoft Graph** in default CI; committing certificate private keys or client secrets; using fuzzy display-name-only search for the IT group; **staged** (disabled) account creation unless later flag; per-row **usage location** CSV column in v1 (reserved for later).

## Further Notes

- **Design alignment:** Implementation should remain traceable to [HLD.md](HLD.md) (flows and boundaries), [IDD.md](IDD.md) (Terraform naming/state when IaC is added), and [SEC.md](SEC.md) (OIDC subjects, pipeline gates, secret classification).
- **Issue tracker handoff:** Create a GitHub issue titled e.g. **“PRD: Bulk Identity Management v1 implementation”**, paste sections or link to this file, and add label **`ready-for-agent`** when the label exists in the repository.
- **ADR policy:** If implementation choices diverge from CONTEXT, record an ADR; do not silently contradict the normative glossary.
