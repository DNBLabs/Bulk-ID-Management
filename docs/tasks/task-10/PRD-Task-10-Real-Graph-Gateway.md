# PRD: Task 10 — Real Graph Gateway + Graph Transient Policy

## Problem Statement

The orchestrator (Task 12) and entry script (Task 13) need a production Graph implementation of the Task 7 gateway contract: UPN existence checks, user create/update, group resolution, and membership ensure. Task 8 provides an in-memory fake for CI; Task 9 establishes certificate auth. Without a real gateway, apply cannot mutate Entra objects. Without a centralized **graph transient policy**, throttling and transient server errors would either fail entire batches prematurely or retry without bounds. Operators and the orchestrator need stable, sanitized failures (`InvalidOperationException`) rather than raw SDK exceptions at the row boundary.

## Solution

Implement **`New-ProvisioningGraphGateway`** as a **private**, **parameterless** builder that:

1. Requires **`Connect-ProvisioningGraph`** to have run successfully.
2. Calls **`Select-MgProfile -Name 'v1.0'`** once (no beta).
3. Returns the same six **ScriptBlock** hashtable as the fake gateway.

Each ScriptBlock invokes **Microsoft.Graph v1.0 cmdlets** through a **private shared wrapper** that applies bounded retries (429, selected 5xx, `Retry-After`, cumulative cap) and maps failures to **`InvalidOperationException`** with operation-specific prefixes.

## User Stories

1. As an orchestrator, I want `TestUpnExists` to return an Object ID or `$null`, so that Task 5 collision logic can run unchanged against live Graph.
2. As an orchestrator, I want `NewUser` to create a member user with a random password I never see, so that **Initial password** policy is enforced at the gateway.
3. As an orchestrator, I want `UpdateUser` to patch only the four documented attributes, so that **Re-run behavior** cannot drift via accidental extra fields.
4. As an orchestrator, I want `GetGroupById` to resolve the IT membership group by Object ID only, so that misconfiguration fails before row processing.
5. As an orchestrator, I want `AddGroupMember` to be idempotent, so that **IT membership ensure** can run on every qualifying apply.
6. As an operator, I want Graph throttling to retry automatically within documented limits, so that small CSV runs survive transient 429/5xx without manual restarts.
7. As an operator, I want clear error messages when Graph calls fail after retries, so that row outcomes are actionable in the aggregate report (Task 11).
8. As a CI pipeline, I want Pester tests with mocked Graph cmdlets, so that default CI never calls Microsoft Graph.

## Implementation Decisions

### Builder and prerequisites

- **Function:** `New-ProvisioningGraphGateway`, **private**, not exported.
- **Parameters:** none. Caller must invoke **`Connect-ProvisioningGraph`** first.
- **Profile:** `Select-MgProfile -Name 'v1.0'` at construction; throw if unavailable.
- **Return:** hashtable with six ScriptBlocks: `TestUpnExists`, `NewUser`, `UpdateUser`, `GetGroupById`, `TestGroupMembership`, `AddGroupMember` (same keys as Task 7/8).
- **IT group:** not cached at build time; group Object ID passed per call.

### Transport and wrapper

- **Transport:** Microsoft.Graph **v1.0 cmdlets** (`Get-MgUser`, `New-MgUser`, `Update-MgUser`, `Get-MgGroup`, `Get-MgGroupMember`, `New-MgGroupMember`, etc.) — not REST-only `Invoke-MgGraphRequest`.
- **Wrapper:** one private function (e.g. `Invoke-ProvisioningGraphCommand`) executes a script block with retry/error mapping; gateway ScriptBlocks call the wrapper, not raw cmdlets ad hoc.

### Graph transient policy (fixed v1 defaults)

- **5** attempts per logical Graph call.
- Retry on **429**, **500**, **502**, **503**, **504** only.
- Exponential backoff: **2s** base (2s → 4s → 8s …).
- **90s** cumulative wait cap per call.
- When **`Retry-After`** is present: wait `max(backoff, Retry-After)` seconds, still enforcing cumulative cap.
- Non-retryable errors and exhausted retries fail immediately (no unbounded loops).
- Not configurable at apply time in v1.

### Error mapping

- After policy exhaustion or on non-retryable failure: throw **`System.InvalidOperationException`** with prefix `Graph <OperationName> failed: …` and sanitized message (no tokens/passwords).
- Preserve original exception as **`InnerException`**.
- No structured error return type; no pass-through of SDK exception types to the orchestrator.

### `TestUpnExists`

- `Get-MgUser -Filter "userPrincipalName eq '<escaped-upn>'"` (OData literal: `'` → `''`; reject null/control characters in UPN).
- Zero results → **`$null`** (not found).
- Exactly one result → that user's **Object ID**.
- More than one → throw `InvalidOperationException` (data integrity).
- Graph failure after retries → throw with `Graph TestUpnExists failed:` — not `$null`.

### `NewUser`

- Caller hashtable has **no password**.
- Allowed mapped fields: `userPrincipalName`, `mailNickname`, `givenName`, `surname`, `displayName`, `department`, `accountEnabled = $true`, optional `usageLocation` when present.
- Accept **camelCase or PascalCase** keys; normalize to Graph camelCase before cmdlet.
- Password: **32** characters; upper, lower, digit, symbol (`!@#$%&*-_+=`); at least one of each class; **`RandomNumberGenerator`**; **`SecureString`** only; **`forceChangePasswordNextSignIn = $true`**.
- Password never logged, returned, or stored on gateway object.
- Returns created user **Object ID** string.

### `UpdateUser`

- Parameters: user **Object ID** (GUID validated) + patch hashtable.
- Allowed patch keys only: `department`, `givenName`, `surname`, `displayName` (camelCase/PascalCase accepted, normalized).
- Any other key → throw `InvalidOperationException` before Graph.
- Maps to `Update-MgUser` by Object ID.

### `GetGroupById`

- Parameter must be group **Object ID** (GUID via `[guid]::TryParse()` before Graph).
- `Get-MgGroup -GroupId`; not found → `InvalidOperationException` (`Graph GetGroupById failed: group not found`).
- No display-name or mailNickname lookup in v1.

### `TestGroupMembership`

- Validate user and group ids as GUIDs.
- `Get-MgGroupMember -GroupId $groupId -Filter "id eq '$userId'" -Top 1` → `$true` if any result, else `$false`.
- Unknown group/user after retries → **throw**, not `$false`.

### `AddGroupMember`

- Idempotent **check-then-add:** call `TestGroupMembership`; if `$true`, return without write; else `New-MgGroupMember` (or equivalent v1.0 cmdlet).
- Matches **IT membership ensure** and fake gateway semantics.

### PSScriptAnalyzer

- Private builders/helpers; suppress or justify only where necessary (e.g. state-changing gateway operations are external Graph mutations — document in suppressions if analyzer flags ScriptBlocks).

## Testing Decisions

- **Mock Graph cmdlets** in `InModuleScope BulkIdentityManagement` (`Get-MgUser`, `New-MgUser`, `Update-MgUser`, `Get-MgGroup`, `Get-MgGroupMember`, `New-MgGroupMember`, `Select-MgProfile`).
- **Wrapper unit tests:** retry on 429 then success; cumulative cap honored; non-retryable 403 does not retry; final failure wraps `InvalidOperationException`.
- **Operation tests (mocked):** `TestUpnExists` empty → `$null`; one user → Object ID; `AddGroupMember` skips add when already member; `UpdateUser` rejects unknown patch key; GUID validation on group/user ids.
- **Security tests (optional file):** password not in exception messages; OData escape for UPN with apostrophe.
- **Test files:** `tests/Task10.RealGateway.Tests.ps1`, `tests/Task10.RealGateway.Retry.Tests.ps1` (or combined), `tests/Task10.RealGateway.Security.Tests.ps1`, `tests/Task10.Closure.Tests.ps1`.
- **Closure:** smoke (builder returns 6 keys), plan checkboxes, PSScriptAnalyzer, scope guard (no Task 11+ implementation files).
- **CI:** no live Graph; all network via mocks.
- **Manual (lab):** documented in IMPLEMENTATION-PLAN — connect with lab app, grant `User.ReadWrite.All`, `Group.Read.All`, `GroupMember.ReadWrite.All`, smoke each operation after permissions; may wait until Task 13 for full CSV path.

## Out of Scope

- **Task 11+** (row outcomes, orchestrator, entry script). Task lock: Task 10 only.
- **`Connect-ProvisioningGraph`** (Task 9) — assumed prerequisite, not reimplemented.
- **Fake gateway changes** (Task 8) except shared contract tests if needed.
- **Orchestrator wiring** (Task 12).
- **Client secret auth**, **beta** profile, **group creation**, **user deletion**, **license assignment**.
- **Configurable retry parameters** at apply time (fixed defaults in v1).
- **Display-name / mailNickname group search**.
- **Live Graph in default CI**.

## Further Notes

- Source layout (expected):
  - `src/Modules/BulkIdentityManagement/Private/New-ProvisioningGraphGateway.ps1`
  - `src/Modules/BulkIdentityManagement/Private/Invoke-ProvisioningGraphCommand.ps1` (or equivalent wrapper name)
  - Optional small helpers: OData escape, property normalization, password generation (private).
- Dot-source new private files from `BulkIdentityManagement.psm1` (match existing Private file pattern).
- Task 10 depends on Tasks **7** (contract), **9** (auth). Task 12 consumes this builder after connect.
- Lab manual verification (2026-05-28): auth session works; Graph application permissions may still need admin consent before gateway smoke succeeds.
