# PRD: Task 8 — In-Memory Fake Graph Gateway

## Problem Statement

The orchestrator (Task 12) needs to create users, check UPN existence, patch attributes, resolve groups, test membership, and add group members — all via the Graph gateway contract defined in Task 7. Default CI must never call Microsoft Graph. Without a working fake implementation, there is no way to unit-test orchestrator logic (dry-run vs apply, skip vs create, idempotent membership ensure, batch error continuation) in an automated, offline, deterministic environment.

## Solution

Replace the `NotImplementedException` stubs in `New-FakeProvisioningGraphGateway` with in-memory logic backed by caller-supplied state dictionaries. Tests pre-seed state to simulate existing users, groups, and memberships, then assert state mutations (or lack thereof for dry-run) after gateway operations execute. The fake mirrors real Graph semantics closely enough that orchestrator code written against the fake will work against the real gateway (Task 10) without structural changes.

## User Stories

1. As a Pester test author, I want to pre-seed an existing user by UPN so that I can verify the orchestrator skips user creation for that row.
2. As a Pester test author, I want `TestUpnExists` to return the user's Object ID when the UPN is seeded, so that I can verify the orchestrator receives the correct identifier.
3. As a Pester test author, I want `TestUpnExists` to return `$null` for an unknown UPN, so that I can verify the orchestrator proceeds to user creation.
4. As a Pester test author, I want `NewUser` to store the user in state and return a generated Object ID, so that I can verify the orchestrator passes the correct fields and receives an identifier for downstream operations.
5. As a Pester test author, I want `NewUser` to throw when creating a user with a UPN that already exists, so that I can catch orchestrator bugs where creation is attempted without a prior existence check.
6. As a Pester test author, I want `UpdateUser` to merge patch fields into an existing user record by Object ID, so that I can verify the orchestrator sends the correct limited attribute patch set.
7. As a Pester test author, I want `UpdateUser` to throw for an unknown Object ID, so that I can verify the orchestrator only patches resolved users.
8. As a Pester test author, I want to pre-seed a group by Object ID so that I can verify the orchestrator resolves the IT membership group before adding members.
9. As a Pester test author, I want `GetGroupById` to throw for an unknown group, so that I can verify the orchestrator handles missing-group failures.
10. As a Pester test author, I want `TestGroupMembership` to return `$true` when a user is already a member and `$false` otherwise, so that I can verify idempotent membership logic.
11. As a Pester test author, I want `AddGroupMember` to be idempotent (no error on duplicate add), so that I can verify the orchestrator's ensure-membership pattern.
12. As a Pester test author, I want `AddGroupMember` to throw when the group doesn't exist in state, so that I can catch test setup bugs and orchestrator mistakes.
13. As a Pester test author, I want to inspect state dictionaries directly after operations, so that I can assert exactly what was created, patched, or left untouched (dry-run).
14. As a CI pipeline, I want zero network calls from the fake gateway, so that default CI stays offline and credential-free.

## Implementation Decisions

- **Single file modification.** Task 8 replaces stub ScriptBlocks in `New-FakeProvisioningGraphGateway` with real in-memory logic. No new source files; the existing Private function file is updated in place.
- **Builder accepts `-State` parameter.** `New-FakeProvisioningGraphGateway -State $state` takes a hashtable with four sub-dictionaries. If `-State` is omitted, builder creates empty defaults internally (convenience for simple tests).
- **State shape.** Four keys on the state hashtable:
  - `Users` — keyed by Object ID (GUID string). Value is the caller's property hashtable with an added `id` field.
  - `UpnIndex` — keyed by lowercase UPN string. Value is Object ID string. Provides O(1) UPN existence lookups.
  - `Groups` — keyed by group Object ID string. Value is whatever the test seeds (typically `@{ id = '...'; displayName = '...' }`).
  - `Members` — keyed by group Object ID string. Value is `[System.Collections.Generic.HashSet[string]]` of user Object ID strings.
- **`TestUpnExists` logic.** Looks up lowercase UPN in `UpnIndex`. Returns the mapped Object ID string if found, `$null` if not. No throw on miss.
- **`NewUser` logic.** Generates Object ID via `[guid]::NewGuid().ToString()`. Checks `UpnIndex` for duplicate UPN (lowercase); throws `InvalidOperationException` if taken. Stores caller hashtable plus `id` in `Users[objectId]`. Adds `UpnIndex[lowercaseUpn] = objectId`. Returns Object ID string. No password material stored (fake skips password generation — CONTEXT says orchestrator never sees password).
- **`UpdateUser` logic.** Looks up user in `Users` by Object ID. Throws `InvalidOperationException` if not found. Merges each key from the patch hashtable into the stored user record (overwrites matching keys).
- **`GetGroupById` logic.** Looks up group in `Groups` by Object ID. Throws `InvalidOperationException` if not found. Returns the stored value.
- **`TestGroupMembership` logic.** Gets or creates empty `HashSet` for the group in `Members`. Returns `HashSet.Contains(userId)`.
- **`AddGroupMember` logic.** Validates group exists in `Groups`; throws `InvalidOperationException` if not. Gets or creates `HashSet` in `Members[groupId]`. Calls `HashSet.Add(userId)` — idempotent (returns `$false` on duplicate, no error).
- **Error type.** All fake errors throw `System.InvalidOperationException` with descriptive messages. Matches Task 4/5 error pattern. Orchestrator catches per row.
- **No user existence validation on `AddGroupMember`.** Fake is a minimal test double, not a full Graph simulator. Orchestrator is responsible for calling operations in correct order. Test assertions catch mistakes.
- **Groups are pre-seeded only.** No group creation operation in the gateway contract (v1 CONTEXT). Tests must seed `$state.Groups` before calling `GetGroupById` or `AddGroupMember`.
- **UPN case-insensitivity.** `UpnIndex` keys are always stored and looked up as `.ToLowerInvariant()`. Matches CONTEXT canonical lowercase UPN.
- **ScriptBlock closures.** Each ScriptBlock in the returned hashtable closes over the `$State` variable. All six operations mutate or read the same shared reference.

## Testing Decisions

- **Test external behavior, not internals.** Tests call gateway operations via the returned ScriptBlock hashtable (same interface the orchestrator uses), then assert on state dictionaries. No mocking of internal helpers.
- **Prior art.** `tests/Task7.GatewayContract.Tests.ps1` — same pattern: `InModuleScope BulkIdentityManagement`, call builder, invoke operations, assert results. Task 8 tests extend this with stateful scenarios.
- **Test file.** `tests/Task8.FakeGateway.Tests.ps1` — all fake behavior tests.
- **Closure file.** `tests/Task8.Closure.Tests.ps1` — smoke, plan checkboxes, PSScriptAnalyzer, scope guard (no Task 9+ files).
- **Scenarios to cover:**
  - `TestUpnExists` returns `$null` for missing UPN
  - `TestUpnExists` returns Object ID for seeded UPN
  - `NewUser` stores user and returns Object ID
  - `NewUser` adds UPN index entry (lowercase)
  - `NewUser` throws on duplicate UPN
  - `NewUser` user record contains caller fields plus `id`
  - `UpdateUser` merges patch into existing user
  - `UpdateUser` throws for unknown Object ID
  - `GetGroupById` returns seeded group
  - `GetGroupById` throws for unknown group
  - `TestGroupMembership` returns `$false` when not a member
  - `TestGroupMembership` returns `$true` after add
  - `AddGroupMember` is idempotent (second add no error)
  - `AddGroupMember` throws when group not seeded
  - Builder with no `-State` creates working empty gateway
  - State is shared reference (operations on returned gateway mutate original state)

## Out of Scope

- **Task 9+ (auth session, real gateway, retries).** Task lock: Task 8 only.
- **Password generation or storage.** Fake explicitly skips this. CONTEXT: orchestrator never receives password.
- **Graph throttling / retry simulation.** Fake is instant, deterministic, always succeeds unless state says otherwise.
- **Group creation.** CONTEXT v1: groups pre-created by admin.
- **User deletion.** Not in gateway contract v1.
- **License assignment.** Not in gateway contract v1.
- **In-batch UPN deduplication.** Out of scope per Task 5 CONTEXT decision; orchestrator concern if needed.

## Further Notes

- Task 7 closure tests check for absence of `Task8*.Tests.ps1` files. That scope guard `It` block was already removed when Task 7 was completed. Task 8 test files will not break prior closure tests.
- The existing Task 7 contract tests (9 tests verifying shape and `NotImplementedException` throws) will break once stubs are replaced with real logic. Those tests must be updated as part of Task 8 to reflect that operations now succeed or throw domain errors instead of `NotImplementedException`.
