# PRD: Task 1 — Repository foundation (PowerShell module shell and pins)

**Normative glossary:** [CONTEXT.md](../CONTEXT.md). **Parent product PRD:** [PRD.md](PRD.md). **Implementation slice:** [IMPLEMENTATION-PLAN.md](IMPLEMENTATION-PLAN.md) — Task 1 only.

**Issue tracker:** This clone had **no `git remote`** at authoring time, so the body below was **not** auto-published to GitHub. When a remote exists, create an issue titled **“PRD: Task 1 — Repository foundation”**, paste everything from **Problem Statement** through **Further Notes**, and apply the **`ready-for-agent`** label.

---

## Problem Statement

Contributors cannot yet land reproducible **PowerShell 7** automation for **bulk provisioning** in this repository because there is no **repository-owned module shell** with a valid **module version manifest**, no **exact-pinned** **Microsoft.Graph** dependency surface aligned with **CONTEXT**, and no guaranteed **ignore policy** for secrets, credentials, **Terraform** local var files, transcripts, and tooling caches that could hold **apply**-sensitive or token material. Without that foundation, later tasks (CSV contract, identity logic, **Graph gateway**, orchestration, **CI**) lack a stable home and a single source of truth for gallery dependency versions, and reviewers cannot rely on **`Test-ModuleManifest`** as a basic quality gate.

## Solution

Establish the **minimal** **BulkIdentityManagement** PowerShell module as the long-lived container for provisioning code: a loadable **root script module**, a **module manifest** that documents the **PowerShell baseline** (**7.2+**, **7.4+** preferred per **CONTEXT**) and pins the **rollup** **Microsoft.Graph** module to **one exact gallery version** (chosen from PSGallery at implementation time—no **`Latest`**). Extend the repository **ignore policy** so common secret paths, certificate material, **`*.tfvars`**, transcripts, and high-risk local operator or tooling artifacts stay untracked per **SEC** and **CONTEXT**. Verify the manifest with **`Test-ModuleManifest`** and confirm no **Entra tenant** secrets or production identifiers enter tracked content.

## User Stories

1. As a **contributor**, I want a **repository-owned PowerShell module** for bulk identity work, so that all later features import from one coherent package boundary.
2. As a **contributor**, I want that module to match the **resolved name** in **CONTEXT** (**BulkIdentityManagement**), so that documentation and code use the same vocabulary.
3. As a **maintainer**, I want the **module manifest** to declare **PowerShell 7.2** as the minimum engine version, so that **Windows PowerShell 5.1** is not implied as supported.
4. As a **maintainer**, I want the manifest to state **Core** edition compatibility, so that **`pwsh`** on Windows and non-Windows runners is the assumed runtime.
5. As a **maintainer**, I want the manifest **description** to reference the **PowerShell baseline** and point readers to **CONTEXT** as normative, so that operators read the contract before running anything.
6. As a **security reviewer**, I want **Microsoft.Graph** versions to be **pinned exactly** in **`RequiredModules`**, so that CI and laptops do not silently float to a new gallery build.
7. As a **security reviewer**, I want the **authoritative pin list** to live **only** on the **module manifest** (not a second root requirements file that can drift), so that **CONTEXT**’s **Module version manifest** decision is honored.
8. As a **contributor**, I want to pin the **rollup** **Microsoft.Graph** module (not a hand-maintained set of **Microsoft.Graph.*** submodules), so that upgrades stay simple and aligned with Microsoft’s packaging.
9. As a **release manager**, I want the chosen **Graph** version to be whatever **stable** version PSGallery exposes when the implementing PR is prepared, so that the pin is honest and reproducible at merge time.
10. As a **contributor**, I want **no** **floating** **`Latest`** resolution anywhere in the pin story, so that **SEC**’s “install from manifest only” posture is not undermined.
11. As a **contributor**, I want **`Test-ModuleManifest`** to succeed on the new manifest, so that broken metadata is caught before any logic lands.
12. As a **contributor**, I want a **root script module** file that imports cleanly with **no exported commands** yet, so that Task 1 stays a scaffold without fake public API.
13. As a **maintainer**, I want the module shell to be the place where **future** **Public** / **Private** functions will live, so that the layout does not churn in Task 3 onward.
14. As a **security reviewer**, I want **`.gitignore`** to exclude **environment files** that often hold secrets, so that `.env`-style leaks are less likely.
15. As a **security reviewer**, I want **ignore rules** for **private keys** and **certificate** extensions, so that **local apply authentication** material never enters git by accident.
16. As a **security reviewer**, I want **Terraform** local state and **`*.tfvars`** ignored (with a safe exception pattern for examples if the repo uses one), so that **IDD**-style local IaC does not commit secrets.
17. As a **security reviewer**, I want **transcripts** and verbose **log** patterns ignored, so that **apply** sessions do not commit **PII** or passwords.
18. As a **security reviewer**, I want common **CLI token caches** for Azure-style tooling ignored where applicable, so that developer machines do not leak session tokens into the repo.
19. As a **security reviewer**, I want optional patterns for **operator-local** parameter files (conventional names only), so that thumbprints and paths stay off the default track without inventing a new secrets format.
20. As a **compliance reviewer**, I want ignore policy to stay aligned with **SEC** and **CONTEXT** language, so that governance docs match what git actually excludes.
21. As a **contributor**, I want the implementing PR to contain **no real tenant IDs**, **no client secrets**, and **no private keys**, so that the first merge is safe to review in any org.
22. As a **new hire**, I want to understand that **default CI** will later validate scripts but **this task** does not require **Pester** yet, so that expectations match the **Implementation Plan** verification for Task 1.
23. As a **platform engineer**, I want the foundation to assume **federated OIDC** and **certificate** stories from **CONTEXT** without implementing auth yet, so that Task 9–10 do not fight the repo layout.
24. As a **contributor**, I want bumping **Microsoft.Graph** to remain a **small intentional PR**, so that security and behavior changes are reviewable.
25. As a **maintainer**, I want **GUID** and metadata in the manifest to be valid and stable for the repository, so that gallery publishing is possible in the future without manifest churn solely from regeneration.
26. As a **contributor**, I want empty **FunctionsToExport** (and related export lists) to be explicit, so that **PSScriptAnalyzer** and imports behave predictably before commands exist.
27. As a **Windows developer**, I want the module to load under **`pwsh`**, so that I am not tempted to test under **5.1** for this repo.
28. As a **Linux CI** maintainer, I want **Core**-only compatibility in the manifest, so that future workflows do not assume **Desktop** edition.
29. As a **security reviewer**, I want **client_secret** filename patterns and credential JSON globs ignored, so that misnamed files do not land in PRs.
30. As a **Terraform user**, I want **`.terraform/`** ignored, so that provider plugins and modules are not committed.
31. As a **contributor**, I want the **Implementation Plan** acceptance bullets for Task 1 to be satisfiable without touching **README** (Task 2), so that this PR stays scoped.
32. As a **maintainer**, I want no **Microsoft Graph** calls introduced in Task 1, so that **CI scope** (“no Graph in default CI”) is not violated early by accident.
33. As a **contributor**, I want the **module root** to be under a conventional **`src/Modules/`** tree, so that tests and scripts can align with the **HLD** layout story.
34. As a **reviewer**, I want a clear **diff** that is mostly manifest, ignore policy, and empty module root, so that review is fast.
35. As a **release manager**, I want the first merge to establish **semantic version** **0.1.0** (or documented alternative) for the module, so that consumers see an explicit pre-1.0 state until behavior stabilizes.
36. As a **contributor**, I want **PrivateData** / gallery metadata blocks left minimal unless needed, so that the manifest stays readable.
37. As a **security champion**, I want **no** **automation principal** secrets or **GitHub** **OIDC** configuration committed in Task 1, so that identity of the app stays in **SEC** / pipeline docs only.
38. As a **contributor**, I want to avoid adding **Pester** tests that **mock** Graph for Task 1, because there is no Graph surface yet—keeping verification **manual** per plan.
39. As a **maintainer**, I want **optional** nested folders (**Public** / **Private**) to be deferred unless the team prefers early structure, so that empty directories are not churn for churn’s sake.
40. As a **contributor**, I want **CONTEXT**’s resolved session notes on pins and module name to remain authoritative, so that this PR implements glossary decisions rather than re-opening them.
41. As a **reviewer**, I want the **rollup** pin to use a **version range** that enforces **exact** match if the manifest format supports it, so that **patch drift** of submodules does not bypass intent.
42. As a **developer**, I want importing the module in **`pwsh`** to succeed without side effects, so that local smoke testing is trivial.
43. As a **repo owner**, I want **no ADR** required for Task 1 unless a hard-to-reverse choice appears, so that governance overhead stays proportional.
44. As a **contributor**, I want **sample CSV** and **entry scripts** explicitly **out of scope** for Task 1, so that Task 3 and Task 13 own those artifacts.
45. As a **contributor**, I want **GitHub Actions workflows** explicitly **out of scope** for Task 1, so that Task 14 owns CI wiring.
46. As a **maintainer**, I want **README** updates explicitly **out of scope** for Task 1, so that Task 2 owns documentation authority messaging.
47. As a **security reviewer**, I want any **new** ignore patterns justified by **SEC** categories (secrets, credentials, transcripts, local config), so that random ignores are not added casually.
48. As a **contributor**, I want the deliverable to unblock **Task 3** (CSV contract) without requiring **Task 2** to merge first, so that parallel work remains possible per dependency notes.
49. As a **stakeholder**, I want this PRD to be pasteable into the **issue tracker** with **`ready-for-agent`**, so that an agent or human can execute Task 1 without re-deriving requirements.

## Implementation Decisions

- **Repository module identity:** Implement the **BulkIdentityManagement** PowerShell module name and canonical **module manifest** location as already resolved in **CONTEXT** (single repository-owned module; manifest holds **`RequiredModules`**).
- **Pinning strategy:** Use **`RequiredModules`** on the **module manifest** as the **only** authoritative list for **Microsoft.Graph** in v1; do **not** introduce a separate root **`requirements.psd1`** unless a later task adds one with an explicit synchronization rule.
- **Graph packaging:** Pin the **rollup** **Microsoft.Graph** gallery module at **one exact version**; do not maintain a bespoke list of **Microsoft.Graph.*** submodule pins for v1 unless **CONTEXT** is formally amended.
- **Exact version selection:** At implementation time, query **PSGallery** for the current **stable** **Microsoft.Graph** version and record that **exact** string in **`RequiredModules`** using whatever manifest fields are required so resolution is **not** “latest” and **not** an open-ended minimum-only range that allows silent upgrades.
- **PowerShell baseline:** Manifest **minimum PowerShell version** and narrative align with **CONTEXT** (**7.2+**, **7.4+** preferred); **Windows PowerShell 5.1** remains unsupported for v1.
- **Edition compatibility:** Declare **PowerShell Core** compatibility so **`pwsh`** is the assumed runtime for development and future CI.
- **Export surface:** Keep **exported function / cmdlet / alias** lists **empty** until later tasks introduce public commands; the **root script module** may contain only comments or a no-op initialization guard.
- **Ignore policy:** Extend the repository **git ignore policy** to cover **SEC** / **CONTEXT** categories: generic secret env files, key material, **Terraform** local state and var files (respecting any committed **example** var exception already used by the repo), transcripts and scratch logs, and narrowly-scoped patterns for local operator configuration and tooling caches that may contain tokens—without inventing a parallel secrets store format.
- **Security hygiene in commits:** The implementing change set must introduce **no** production **Entra tenant** identifiers used as authentication secrets, **no** **client secrets**, **no** private keys, and **no** populated **Terraform** var files.
- **Quality gate for metadata:** **`Test-ModuleManifest`** must succeed against the new **module manifest** before merge.
- **Deep module posture (forward-looking):** Task 1 intentionally delivers a **shallow** shell; **deep modules** (**CSV contract**, **identity derivation**, **Graph gateway**, orchestration) begin in later tasks but must **nest inside** this module boundary to preserve testability and import graphs.

## Testing Decisions

- **Good tests (Task 1 era):** Prefer **observable outcomes**: manifest validates, module imports under **`pwsh`**, and repository policy excludes the right **artifact classes**. Avoid testing **implementation trivia** (e.g., internal folder names) unless they encode a security or packaging contract.
- **Modules covered by automated tests in Task 1:** **None required** by the **Implementation Plan** verification for this task; deterministic **Pester** coverage begins with **CSV** and rules in later tasks.
- **Prior art:** The repository does not yet contain **Pester** suites for this product; Task 1 establishes the **manifest** precedent that future CI can **`Test-ModuleManifest`** against. Optional follow-up (not part of Task 1 closure): a tiny **manifest regression** test if the team wants CI to fail on invalid **`RequiredModules`** syntax—only add if it does not pull **Graph** into default CI.

## Out of Scope

- **Task 2** and beyond: **README**, operator runbooks, **CSV** parsing, **name mapping**, **UPN** collision policy, **IT department rule**, **Graph gateway** (real or fake), **auth session** wiring, **orchestrator**, **entry script**, **default CI workflows**, optional **manual** tenant-mutating workflow, **sample CSV**, lab checklist, **PSScriptAnalyzer** settings file, and any **Microsoft Graph** API calls.
- **Behavioral automation:** No user creation, no group membership changes, no **dry run** or **apply** logic.
- **Infrastructure as code:** No **Terraform** or **ARM** resource definitions required to close Task 1.
- **Container builds**, **image scanning**, and **Dockerfile** hardening—explicitly deferred until such artifacts exist.

## Further Notes

- **Normative alignment:** If this PRD ever disagrees with **CONTEXT.md**, **CONTEXT** wins; this document is a **slice PRD** for execution tracking.
- **Issue publication:** After **`git remote add origin …`**, publish this content as a GitHub issue and label **`ready-for-agent`** per the parent **PRD** triage convention.
- **Module / test expectation check (skill merge):** Task 1’s only build artifact is the **BulkIdentityManagement** shell plus **ignore policy** updates; no automated test modules are required to close the task. If you want a **manifest smoke test** in **Pester** earlier than Task 14, treat that as a **stretch** and track it separately so Task 1 stays small.
