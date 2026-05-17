# PRD: Task 4 — Name mapping and MailNickname normalization

**Normative glossary:** [CONTEXT.md](../../../CONTEXT.md). **Parent product PRD:** [PRD.md](../../PRD.md). **Implementation slice:** [IMPLEMENTATION-PLAN.md](../../IMPLEMENTATION-PLAN.md) — Task 4 only.

**Design references:** [HLD.md](../../HLD.md), [SEC.md](../../SEC.md). **Background only:** [init-project.txt](../../init-project.txt).

**Issue tracker:** Published as [DNBLabs/Bulk-ID-Management#3](https://github.com/DNBLabs/Bulk-ID-Management/issues/3) with the **`ready-for-agent`** label.

**Prerequisite:** Task 3 **`Import-ProvisioningCsv`** and stable **provisioning row** objects are complete.

---

## Problem Statement

Task 3 delivers validated **provisioning row** objects from CSV, but downstream **apply** and **Identity derivation** still lack a single, deterministic boundary that turns each row into Entra-ready **GivenName**, **Surname**, **DisplayName**, and a normalized **MailNickname**. Without Task 4, operators cannot rely on consistent display names and mail aliases (accents, multi-word names, overrides, invalid punctuation) in **Pester** or **CI validation gates**, and Task 5 **UPN** composition would duplicate or diverge from **CONTEXT** rules. Name and nickname logic must stay pure (no **Microsoft Graph**) so default CI remains offline and fast.

## Solution

Implement a **Name mapping and MailNickname normalization** deep module inside **BulkIdentityManagement**: a public **`Get-MappedProvisioningIdentity -ProvisioningRow`** command that accepts one **provisioning row**, applies **Name mapping** (defaults plus optional CSV overrides), derives or normalizes **MailNickname** per **CONTEXT**, and returns a **mapped provisioning identity** object. Failures for invalid nicknames throw **`System.InvalidOperationException`** with **physical line number** in the message. The input row is not mutated; **UserPrincipalName** on the row is left for Task 5 **Identity derivation**. Private helpers encapsulate trim/collapse, override resolution, and the nickname normalization pipeline.

## User Stories

1. As an **identity operator**, I want **GivenName** derived from **FirstName** by default, so that Entra **givenName** matches my CSV given name.
2. As an **identity operator**, I want **Surname** derived from **LastName** by default, so that Entra **surname** matches my CSV family name.
3. As an **identity operator**, I want **DisplayName** built from **FirstName**, a single space, and **LastName**, so that directory display names look professional.
4. As an **identity operator**, I want leading and trailing whitespace removed and internal runs of whitespace collapsed in mapped names, so that double spaces from exports do not appear in Entra.
5. As an **identity operator**, I want optional CSV **GivenName** to override the default when present on the row, so that preferred names (e.g. **Bob** instead of **Robert**) apply to **givenName** and downstream nickname rules.
6. As an **identity operator**, I want optional CSV **Surname** and **DisplayName** to override defaults the same way, so that legal or display exceptions are representable in data.
7. As an **identity operator**, I want **José**, **García**, and similar characters preserved in **GivenName**, **Surname**, and **DisplayName**, so that human-facing fields match how I typed them in CSV.
8. As an **identity operator**, I want default **MailNickname** built from mapped **GivenName** and **Surname** joined with a dot, so that nicknames align with names sent to Entra when overrides exist.
9. As an **identity operator**, I want **MailNickname** lowercased and accents stripped, so that aliases are ASCII-safe for UPN and mail alias conventions.
10. As an **identity operator**, I want German **ß** expanded to **ss** in **MailNickname** only, so that names like **Weiß** produce predictable aliases.
11. As an **identity operator**, I want spaces removed from **MailNickname** after joining (e.g. **Mary Jane** + **Watson** → **maryjane.watson**), so that aliases satisfy typical **mailNickname** constraints.
12. As an **identity operator**, I want hyphens kept in **MailNickname** when part of a name (e.g. **jean-luc.picard**), so that hyphenated names remain readable.
13. As an **identity operator**, I want apostrophes and other unsafe punctuation stripped from **MailNickname** (e.g. **O'Brien** → **obrien**), so that Graph validation is less likely to fail.
14. As an **identity operator**, I want optional CSV **MailNickname** to override the derived default, so that I can force a specific alias when automation’s default is wrong.
15. As an **identity operator**, I want CSV **MailNickname** values run through the same normalization pipeline as derived nicknames, so that casing and accents in my file do not bypass rules.
16. As an **identity operator**, I want invalid nicknames (empty or no letters after normalization) to fail that row with a clear line number, so that I can fix data before re-running **apply**.
17. As an **identity operator**, I want repeated dots or hyphens collapsed and edge punctuation trimmed on nicknames, so that **John..Smith** does not produce malformed aliases.
18. As a **contributor**, I want **`Get-MappedProvisioningIdentity`** exported from **BulkIdentityManagement**, so that orchestration and tests share one entry point.
19. As a **contributor**, I want the public command to accept a **provisioning row** object from **`Import-ProvisioningCsv`**, so that the pipeline is import → map per row → derive UPN later.
20. As a **contributor**, I want the input **provisioning row** left unchanged, so that CSV fields remain available for **Department**, **UserPrincipalName**, and auditing.
21. As a **contributor**, I want **Pester** tests for name defaults, overrides, diacritics, nickname edge cases, and failure messages, so that **CI validation gates** protect behavior without **Microsoft Graph**.
22. As a **security reviewer**, I want Task 4 to perform no **Apply** or Graph operations, so that default CI needs no tenant credentials.
23. As a **maintainer**, I want nickname normalization in private helpers, so that the public surface stays narrow and stable.
24. As a **developer**, I want **mapped provisioning identity** objects to use PascalCase properties (**GivenName**, **MailNickname**, etc.), so that they align with **provisioning row** naming in PowerShell.
25. As an **identity operator**, I want **DisplayName** override to replace the full default display string when **DisplayName** is supplied on the row, so that I can set an explicit display label without changing given/surname unless I choose to.
26. As an **identity operator**, I want default **displayName** to still use **FirstName** and **LastName** (not **GivenName** override alone) when only **GivenName** is overridden, so that legal surname appears in display unless I override **DisplayName** explicitly.
27. As a **contributor**, I want invalid nickname failures to throw **`System.InvalidOperationException`**, so that callers match Task 3 fail-closed style and orchestrators can map to **row outcome** **failed**.
28. As a **contributor**, I want error messages to cite **SourceLineNumber** as the physical file line, so that operators match Excel and editor line numbers.
29. As a **maintainer**, I want Task 4 acceptance criteria from the implementation plan satisfied, so that Task 4 can be marked complete without starting Task 5.
30. As a **stakeholder**, I want this PRD published with **`ready-for-agent`**, so that implementation can proceed without re-grilling decisions already captured in **CONTEXT**.

## Implementation Decisions

### Modules to build or modify

| Module / unit | Role | Public surface |
|---------------|------|----------------|
| **Mapped provisioning identity** | Deep module: **Name mapping** + **MailNickname** for one **provisioning row** | **`Get-MappedProvisioningIdentity -ProvisioningRow <object>`** |
| **Name mapping** (private) | Trim/collapse; defaults from **FirstName**/**LastName**; apply **GivenName**/**Surname**/**DisplayName** overrides; build **DisplayName**; preserve diacritics | Not exported |
| **MailNickname normalization** (private) | Dot-join mapped names or normalize CSV override; Form D + strip marks; **ß→ss**; lowercase; remove spaces; charset **`[a-z0-9.-]`**; collapse/trim; validate | Not exported |
| **BulkIdentityManagement** (host) | Export public function; dot-source private scripts; no Graph calls | Add **`Get-MappedProvisioningIdentity`** to **FunctionsToExport** |

**Processing order inside `Get-MappedProvisioningIdentity`:**

1. Validate **ProvisioningRow** has required properties (**SourceLineNumber**, **FirstName**, **LastName**, **Department** at minimum).
2. **Name mapping** → **GivenName**, **Surname**, **DisplayName** (overrides applied; diacritics preserved).
3. **MailNickname** — if row has **MailNickname** property, normalize that string; else derive base from mapped **GivenName** + **.** + mapped **Surname**, then normalize.
4. Validate final **MailNickname**; on failure, throw **`System.InvalidOperationException`** including physical line from **SourceLineNumber**.
5. Return new object; do not mutate input row.

### **`Get-MappedProvisioningIdentity` contract**

- **Parameter:** **`-ProvisioningRow`** (mandatory)—object emitted by **`Import-ProvisioningCsv`**.
- **Success:** returns one **mapped provisioning identity** object.
- **Failure:** terminating **`System.InvalidOperationException`** when nickname invalid; message includes physical line number (e.g. `Could not derive a valid MailNickname for provisioning row on physical line 4.`).

### **Mapped provisioning identity object shape**

| Property | Always present | Notes |
|----------|----------------|-------|
| **SourceLineNumber** | Yes | Copied from row |
| **GivenName** | Yes | Mapped; may differ from **FirstName** if override |
| **Surname** | Yes | Mapped |
| **DisplayName** | Yes | Mapped |
| **MailNickname** | Yes | Normalized; derived or from CSV override |

**Not set on this object:** **UserPrincipalName**, **Department**, **FirstName**, **LastName** (remain on input row).

### **Name mapping rules** (from **CONTEXT** / grill session)

- **GivenName** default: **FirstName**; **Surname** default: **LastName**; **DisplayName** default: **FirstName** + space + **LastName** (each part trim + collapse internal whitespace).
- Overrides: non-empty **GivenName**, **Surname**, or **DisplayName** on row replace corresponding output; same trim/collapse on override value.
- **Diacritics preserved** on **GivenName**, **Surname**, **DisplayName** only.
- **DisplayName** override replaces entire default display string when **DisplayName** column present and non-empty.
- **DisplayName** default always uses CSV **FirstName** and **LastName** (not mapped **GivenName**/**Surname**), so e.g. **FirstName** `Robert`, **GivenName** `Bob` yields **GivenName** `Bob`, **DisplayName** `Robert Smith`, **MailNickname** `bob.smith` unless **DisplayName** is also overridden.

### **MailNickname rules** (Task 4 slice of **Identity derivation**)

- **Default base:** mapped **GivenName** + **`.`** + mapped **Surname** (post-override), each part trim + collapse spaces before join.
- **CSV override:** if row has **MailNickname**, use that string as input to the **same** normalization pipeline (not pass-through).
- **Normalization pipeline:** lowercase; Unicode **Form D** + remove non-spacing marks; explicit **ß → ss**; remove all spaces; keep only **`[a-z0-9.-]`**; collapse repeated **`.`** and **`-`**; trim leading/trailing **`.`** and **`-`**.
- **Validation:** non-empty and at least one **`a-z`** letter; else throw with **SourceLineNumber**.

**Examples (derived nickname, no CSV **MailNickname**):**

| FirstName | LastName | GivenName override | MailNickname |
|-----------|----------|-------------------|--------------|
| José | García | — | jose.garcia |
| Mary Jane | Watson | — | maryjane.watson |
| Robert | Smith | Bob | bob.smith |
| Anne | O'Brien | — | anne.obrien |
| Jean-Luc | Picard | — | jean-luc.picard |
| Björn | Weiß | — | bjorn.weiss |

### **Dependencies and isolation**

- **Depends on** Task 3 **provisioning row** shape (properties and **SourceLineNumber** semantics).
- Do **not** import or call **Microsoft.Graph** in Task 4 code or Task 4 **Pester** tests.
- Do **not** implement **UserPrincipalName** composition, collision suffixes, **Test-UpnExists**, tenant domain suffix (**Task 5**).
- Do **not** implement **IT department rule**, **Graph gateway**, orchestration, reporting, entry script, CI workflow, or sample CSV (Tasks 5–17).

### **Documentation alignment**

- **CONTEXT.md** is normative; grill session resolutions for Task 4 are already merged there (**Mapped provisioning identity**, override behavior, nickname pipeline).
- Parent implementation plan Task 4 checkbox “reserved for future” on overrides is **superseded** by **CONTEXT**: overrides are **active in v1**; the **v1 sample CSV** stays minimal (core columns only)—document in README only if Task 4 touch requires a one-line note; no Task 16 sample work in this slice.

### **No ADR required**

Nickname and mapping rules are normative in **CONTEXT.md**; use an ADR only if implementation discovers a hard-to-reverse transliteration choice beyond Form D + **ß→ss**.

## Testing Decisions

### What makes a good test

- Assert **observable behavior** of **`Get-MappedProvisioningIdentity`**: output property values, throw vs success, and stable substrings in exception messages (**physical line**).
- Build input rows as **PSCustomObject** with the same property names Task 3 emits (no need to read a CSV file for every case unless integrating import → map in a few smoke tests).
- Avoid asserting private function names unless they become a deliberate stable API (they should not).

### Modules to test

| Module | Test? |
|--------|-------|
| **`Get-MappedProvisioningIdentity`** | **Yes** — primary **Pester** suite for Task 4 |
| **BulkIdentityManagement** manifest | **Yes** — **FunctionsToExport** includes **`Get-MappedProvisioningIdentity`** after implementation |
| Private name/nickname helpers | **No** direct tests; covered via public command |

### Recommended test scenarios (non-exhaustive)

- Minimal row: **FirstName**/**LastName** only → expected **GivenName**, **Surname**, **DisplayName**, derived **MailNickname**.
- **GivenName** override (Robert / Bob) → **GivenName** `Bob`, **MailNickname** `bob.smith`.
- **Surname**, **DisplayName** overrides independently.
- Diacritics preserved on mapped names; stripped in **MailNickname** (José / García).
- Multi-word first name → **maryjane.watson**; hyphenated → **jean-luc.picard**; apostrophe → **anne.obrien**.
- **ß** / umlaut → **bjorn.weiss** (nickname path).
- CSV **MailNickname** override: `ADA.LOVELACE` → `ada.lovelace`; invalid `!!!` → throw with line number.
- Collapse `John..Smith` → `john.smith` (or equivalent per rules).
- Input row not mutated after call (property bag unchanged).
- Optional: one test chaining **`Import-ProvisioningCsv`** → **`Get-MappedProvisioningIdentity`** on a tiny UTF-8 fixture.

### Prior art

- Task 3 **Pester** tests: **`Task3.*.Tests.ps1`**, row materialization patterns, **`Should -Throw`** with message assertions, module import in **BeforeAll**.
- Task 1 manifest tests for export list patterns.

### Manual verification (implementation plan)

- In **pwsh**, import module, map a row from a known good CSV row object, inspect **GivenName** / **MailNickname** for one accented and one override case.

## Out of Scope

- **UserPrincipalName** build, tenant domain suffix, injectable **UPN exists** check, numeric collision suffix (**Task 5**).
- **IT department rule** (**Task 6**).
- **Graph gateway**, authentication, orchestration, **row outcome** reporting, entry script (**Tasks 7–13**).
- CI workflow wiring beyond adding tests that will run under existing **Invoke-Pester** habits (**Task 14**).
- Sample CSV / runbook (**Task 16**); changing **UserPrincipalName** on the row or returning it from **`Get-MappedProvisioningIdentity`**.
- **MailNickname** collision handling and any live Graph **mailNickname** uniqueness check.
- README overhaul; reserved-column “future” wording that contradicts **CONTEXT** (overrides are in v1; sample file shape unchanged).

## Further Notes

- **Normative alignment:** If this PRD disagrees with **CONTEXT.md**, **CONTEXT** wins.
- **Task lock:** Implement **Task 4** only; do not start **Task 5** or later in the same delivery unless explicitly expanded.
- **Implementation handoff:** Update parent **Implementation Plan** Task 4 checkboxes when acceptance criteria are met; optional **`docs/tasks/task-4/PLAN-*.md`** when implementation begins.
- **Module naming:** **BulkIdentityManagement** per **CONTEXT**.
- **Graph attributes vs PowerShell properties:** Entra uses **givenName** / **surname** / **displayName** / **mailNickname** in Graph API; this module’s mapped object uses PascalCase (**GivenName**, etc.) for consistency with **provisioning row** objects; gateway/orchestrator maps to Graph when calling **v1.0** later.
