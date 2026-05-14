# PRD: Task 2 — README aligned with documentation authority

**Normative glossary:** [CONTEXT.md](../../CONTEXT.md). **Parent product PRD:** [PRD.md](../PRD.md). **Implementation slice:** [IMPLEMENTATION-PLAN.md](../IMPLEMENTATION-PLAN.md) — Task 2 only.

**Design references:** [HLD.md](../Design/HLD.md), [IDD.md](../Design/IDD.md), [SEC.md](../Design/SEC.md). **Background only:** [init-project.txt](../init-project.txt).

**Issue tracker:** Published as [DNBLabs/Bulk-ID-Management#1](https://github.com/DNBLabs/Bulk-ID-Management/issues/1) with the **`ready-for-agent`** label.

---

## Problem Statement

New readers do not yet have a repository landing page that explains the documentation authority for **Bulk Identity Management**. The project already has a normative **CONTEXT** glossary, design documents, and an implementation plan, but without a root **README** a maintainer or operator may read the informal brief first, misunderstand **CI scope**, assume **apply** commands are ready, or miss the security posture around certificate material and the absence of a default **client secret** path.

Task 2 must solve that documentation-entry problem without starting later implementation work such as **Provisioning CSV format** parsing, **Identity derivation**, **Graph gateway**, **Authentication session**, orchestration, sample CSVs, or operator runbooks.

## Solution

Create a root **README** that acts as a thin authority landing page. It opens with **CONTEXT.md** as the normative glossary and behavioral contract, then summarizes the safe operating model: default **CI validation gates** are validate-only and do not call **Microsoft Graph**; real **apply** follows the documented **apply path**; operators must run **dry run** before mutating **apply**; and local **apply authentication** uses certificate-based client credentials with certificate/private key material outside the repository. The README links the parent **PRD**, **HLD**, **IDD**, **SEC**, implementation plan, and the informal **init-project** background while making clear that **CONTEXT** prevails on conflicts.

The README should also state the repository's current implementation status. Task 1 foundation exists: the **BulkIdentityManagement** module scaffold lives under the repository module tree, targets **PowerShell 7.2+** with **7.4+** preferred, and pins the rollup **Microsoft.Graph** module via the module manifest. Task 2 should not imply an operator entry command exists yet; instead, it should point to the implementation plan for remaining work and explicitly mark CSV parsing, identity logic, Graph integration, apply orchestration, and full operator runbooks as later tasks.

## User Stories

1. As a **new maintainer**, I want the repository README to point me to **CONTEXT.md** first, so that I understand the normative behavioral contract before reading implementation notes.
2. As an **identity operator**, I want the README to distinguish **apply** from **CI scope**, so that I do not expect default CI to mutate the **Entra tenant**.
3. As a **security reviewer**, I want the README to state that default CI does **not** call **Microsoft Graph**, so that tenant credentials are not required for routine PR checks.
4. As a **contributor**, I want the README to summarize **CI validation gates**, so that I know the default posture is **PSScriptAnalyzer** and **Pester** for deterministic behavior as the implementation matures.
5. As a **contributor**, I want the README to say **Microsoft Graph** access is outside default CI, so that tests and docs do not accidentally depend on live tenant connectivity.
6. As an **identity operator**, I want the README to state **dry-run before mutating apply**, so that safe review becomes the documented operating habit.
7. As an **identity operator**, I want **Dry run** described as a read-only plan mode, so that I know it must not create users, rotate passwords, or add group members.
8. As an **identity operator**, I want the README to describe the primary **apply path** as local or controlled-runner execution, so that I do not assume every push performs provisioning.
9. As a **security reviewer**, I want the README to say certificate/private key material stays outside the repo, so that **local apply authentication** does not encourage committing secrets.
10. As a **security reviewer**, I want the README to state that **client secret** authentication is not the default path, so that long-lived secrets are not introduced casually.
11. As an **identity operator**, I want the README to use **Automation principal** and **Local apply authentication** consistently with **CONTEXT**, so that docs and later scripts share the same vocabulary.
12. As a **platform engineer**, I want the README to identify **PowerShell 7.2+** and **7.4+ preferred**, so that local setup matches the **PowerShell baseline**.
13. As a **contributor**, I want the README to mention the current **BulkIdentityManagement** module scaffold, so that I know where future implementation work belongs.
14. As a **maintainer**, I want the README to mention the repository-owned **module version manifest**, so that dependency pinning is visible without duplicating manifest internals.
15. As a **security reviewer**, I want the README to say **Microsoft.Graph** versions are pinned and not floating **Latest**, so that dependency governance is visible from the landing page.
16. As a **new reader**, I want the README to link the parent **PRD**, so that I can understand the product goal beyond the current slice.
17. As a **new reader**, I want the README to link the **HLD**, so that I can understand architecture and boundary flow.
18. As a **new reader**, I want the README to link the **IDD**, so that I can understand future infrastructure governance without confusing it with core workstation **apply**.
19. As a **security reviewer**, I want the README to link **SEC**, so that secret handling, OIDC posture, and least-privilege expectations are easy to find.
20. As a **contributor**, I want the README to link the **Implementation Plan**, so that current task status and future task order are discoverable.
21. As a **new reader**, I want **init-project** linked only as background, so that an informal brief is not mistaken for the behavioral contract.
22. As a **maintainer**, I want the README to say **CONTEXT** prevails on conflicts, so that authority is unambiguous.
23. As an **identity operator**, I want the README to avoid provisional apply command examples before the entry script exists, so that I do not copy commands that are not supported yet.
24. As a **contributor**, I want the README to mark implementation as in progress, so that later tasks are not assumed complete.
25. As a **contributor**, I want a short **not yet implemented** boundary, so that **Provisioning CSV format**, **Identity derivation**, **Graph gateway**, **Authentication session**, **Apply** orchestration, and runbook work remain in their assigned tasks.
26. As a **reviewer**, I want Task 2 to touch documentation only, so that the diff is easy to verify and does not hide behavior changes.
27. As a **security reviewer**, I want the README to avoid real tenant IDs, client IDs, certificate thumbprints, or production group identifiers, so that the documentation does not leak environment details.
28. As a **security reviewer**, I want example values, if any, to be obvious placeholders, so that readers do not confuse samples with real credentials.
29. As an **identity operator**, I want the README to warn that **apply** output can be sensitive, so that operators do not commit transcripts or logs.
30. As a **support engineer**, I want the README to reference future **Row outcome** and aggregate reporting at a high level only, so that expectations point to later implementation tasks.
31. As a **maintainer**, I want the README to avoid repeating the entire **CONTEXT** glossary, so that there is one source of truth for terms.
32. As a **contributor**, I want root-relative links to resolve from GitHub and local Markdown preview, so that documentation is navigable.
33. As a **reviewer**, I want the README to use the current actual design-doc paths, so that links work even if older documents have stale relative references.
34. As a **contributor**, I want Task 2 to create or reference a dedicated task plan when implementation begins, so that state tracking does not get mixed into the Task 1 plan.
35. As a **maintainer**, I want the parent implementation plan checkboxes updated only when Task 2 is actually implemented, so that task state stays honest.
36. As a **developer**, I want no **Pester** or **Graph** tests introduced for Task 2, so that a documentation task does not pretend to validate future behavior.
37. As a **developer**, I want local verification to be manual README rendering and link review, so that Task 2 stays proportional.
38. As a **developer**, I want optional foundation smoke commands limited to existing Task 1 artifacts, so that README verification does not start **Task 3** or **Task 13**.
39. As a **security reviewer**, I want README language to reinforce **OIDC** for CI credentials where applicable, so that repository-stored client secrets remain out of scope.
40. As a **platform engineer**, I want the README to mention optional manual **workflow_dispatch** apply only as a future/optional path, so that default PR checks remain validate-only.
41. As an **identity operator**, I want the README to explain that tenant-mutating automation is controlled and explicit, so that accidental mutation from repository events is not expected.
42. As a **new maintainer**, I want a concise document map, so that I can decide whether to read **CONTEXT**, **PRD**, **HLD**, **IDD**, **SEC**, or the implementation plan next.
43. As a **contributor**, I want the README to avoid adding architectural decisions that are not already in **CONTEXT** or design docs, so that Task 2 documents rather than redesigns.
44. As a **maintainer**, I want no ADR for Task 2 unless the README chooses a surprising hard-to-reverse documentation authority model, so that governance overhead stays small.
45. As a **stakeholder**, I want this PRD to be pasteable into the issue tracker with **`ready-for-agent`**, so that a human or agent can implement Task 2 without re-grilling the decisions.

## Implementation Decisions

- **README as authority landing page:** The root **README** is not the normative contract; it routes readers to **CONTEXT.md** first and summarizes the most important operating constraints.
- **Thin scope:** The README is intentionally a thin landing page, not a full operator runbook. Detailed apply commands, sample CSVs, lab checklists, and parameter walkthroughs belong to later tasks after the entry surface exists.
- **Documentation hierarchy:** **CONTEXT.md** is normative. The parent **PRD**, **HLD**, **IDD**, and **SEC** are design and requirements references. **init-project** is background only and loses to **CONTEXT** on conflicts.
- **Current implementation status:** The README should say implementation is in progress and link the **Implementation Plan** for task status.
- **Task 1 foundation summary:** The README may mention the existing **BulkIdentityManagement** module scaffold, **PowerShell baseline**, and pinned **Microsoft.Graph** manifest as foundation, but must not imply exported provisioning commands are available.
- **CI language:** The README states the invariant that default CI is validate-only and does not call **Microsoft Graph** or require tenant credentials. If CI files already exist, describe them as current validate-only foundation while leaving full CI completion to the later CI task.
- **Apply language:** The README summarizes the **apply path** and **dry-run before mutating apply** requirement from **CONTEXT** without giving unsupported command examples.
- **Credential language:** The README states certificate/private key material stays outside the repository and **client secret** is not the default documented path.
- **Secret hygiene:** The README must not include real **tenant IDs**, **client IDs**, certificate thumbprints, private-key paths, group object IDs, or production identifiers. Placeholder examples, if any, must be obviously fake.
- **Not-yet-implemented boundary:** The README should explicitly avoid claiming completion of **Provisioning CSV format**, **Name mapping**, **Identity derivation**, **IT department rule**, **Graph gateway**, **Authentication session**, **Row outcome** reporting, **Apply** orchestration, entry script, sample CSV, runbook, or lab checklist.
- **Link correctness:** README links should use actual current repo paths from the repository root, including **Design** subfolder paths for **HLD**, **IDD**, and **SEC**.
- **State tracking:** When Task 2 is implemented, maintain a dedicated Task 2 plan/checklist and update the parent **Implementation Plan** only after Task 2 acceptance criteria are satisfied.

## Testing Decisions

- **Good tests for Task 2:** The right verification is observable documentation quality: the README opens with **CONTEXT** as normative, the links resolve relative to the repository root, the security statements are present, and no unsupported behavior is implied.
- **Automated test scope:** No automated **Pester** tests are required for this PRD slice. Task 2 is documentation-only and should not introduce test files for future code behavior.
- **Manual verification:** Render or preview the README, click or inspect all relative links, and review the document for prohibited content such as real tenant identifiers, client secrets, private keys, or apply commands that do not exist yet.
- **Foundation verification allowed:** The README may include small local smoke commands for existing Task 1 artifacts, such as module manifest validation or import, as long as those commands do not call **Microsoft Graph** or imply provisioning behavior.
- **Prior art:** Task 1 established the pattern of slice PRDs and task-local acceptance tracking. Task 2 should follow that style but keep verification proportional to documentation.

## Out of Scope

- Implementing or documenting working **Provisioning CSV format** parsing.
- Implementing **Name mapping**, **Identity derivation**, **UPN** collision handling, or **IT department rule** logic.
- Implementing the **Graph gateway**, fake gateway, retry policy, **Authentication session**, or real **Microsoft Graph** calls.
- Implementing **Row outcome** formatting, aggregate reports, output redaction code, or exit code policy.
- Implementing **Apply** orchestration, entry scripts, exported commands, or operator parameters.
- Creating sample CSVs, full operator runbooks, or lab integration checklists.
- Creating or changing default CI workflows, optional manual **workflow_dispatch** apply workflows, OIDC federation, or GitHub Environments.
- Changing **CONTEXT**, **HLD**, **IDD**, **SEC**, or parent **PRD** content unless a broken README link requires a narrowly scoped correction.
- Adding real tenant identifiers, production **Object ID** values, certificate material, secrets, or populated local config examples.
- Starting **Task 3** or any later implementation task.

## Further Notes

- **Normative alignment:** If this PRD disagrees with **CONTEXT.md**, **CONTEXT** wins.
- **Implementation handoff:** The implementing agent should create or update a dedicated Task 2 plan file before editing the README, then update both that plan and the parent **Implementation Plan** only after Task 2 is complete.
- **No ADR expected:** The README authority model is already resolved in **CONTEXT**; an ADR is unnecessary unless implementation introduces a new hard-to-reverse documentation governance decision.
