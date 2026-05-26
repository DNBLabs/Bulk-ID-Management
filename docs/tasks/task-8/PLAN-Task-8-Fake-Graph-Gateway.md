# Plan: Task 8 — In-Memory Fake Graph Gateway

**Parent:** [IMPLEMENTATION-PLAN.md](../../IMPLEMENTATION-PLAN.md) Task 8.
**PRD:** [PRD-Task-8-Fake-Graph-Gateway.md](PRD-Task-8-Fake-Graph-Gateway.md).
**Normative:** [CONTEXT.md](../../../CONTEXT.md) — Fake graph gateway internals.

## Goal

Replace `NotImplementedException` stubs in `New-FakeProvisioningGraphGateway`
with in-memory logic backed by caller-supplied state dictionaries. Update
Task 7 contract tests that now break (stubs no longer throw
`NotImplementedException`).

## Sub-tasks

### Phase 1: Builder + TestUpnExists (tracer bullet)

- [x] **A — Add `-State` parameter and default initialization.** Builder accepts optional `-State [hashtable]`; creates empty defaults when omitted. ScriptBlocks close over `$State` via `.GetNewClosure()`.
- [x] **B — Implement `TestUpnExists`.** Lowercase UPN lookup in `$State.UpnIndex`. Return Object ID or `$null`. Tests: missing UPN -> `$null`, seeded UPN -> Object ID, case-insensitive.

### Phase 2: User operations

- [x] **C — Implement `NewUser`.** Generate GUID Object ID, check `UpnIndex` for duplicate (throw `InvalidOperationException`), store caller hashtable + `id` in `Users`, add `UpnIndex` entry, return Object ID. Tests: stores + returns ID, adds index entry (lowercase), record has caller fields + `id`, duplicate UPN throws.
- [x] **D — Implement `UpdateUser`.** Look up by Object ID in `Users`, throw if not found, merge patch keys. Tests: merges patch, throws for unknown ID.

### Phase 3: Group and membership operations

- [x] **E — Implement `GetGroupById`.** Look up in `$State.Groups`, throw if missing, return stored value. Tests: returns seeded group, throws for unknown.
- [x] **F — Implement `TestGroupMembership`.** Get or create `HashSet` in `$State.Members[groupId]`, return `.Contains(userId)`. Tests: `$false` when not member, `$true` after add.
- [x] **G — Implement `AddGroupMember`.** Validate group in `$State.Groups` (throw if missing), get or create `HashSet`, `.Add(userId)` (idempotent). Tests: adds member, idempotent, throws when group not seeded.

### Phase 4: Contract test migration + closure

- [x] **H — Update Task 7 contract tests.** Six `NotImplementedException` tests updated to verify actual behavior (returns `$null`, returns Object ID, throws `InvalidOperationException`). Shape tests (hashtable, 6 keys, ScriptBlock types) kept as-is.
- [x] **I — Builder convenience test.** No `-State` param -> works with empty state. Shared reference test: mutate via gateway, assert state dict reflects changes.
- [x] **J — Closure.** `Task8.Closure.Tests.ps1`: smoke, plan checkboxes, PSScriptAnalyzer clean, scope guard (no Task 9+ files).

## Checkpoint

- [x] All `tests/Task7*.Tests.ps1` pass (updated contract tests).
- [x] All `tests/Task8*.Tests.ps1` pass.
- [x] Full Pester suite green.
- [x] PSScriptAnalyzer clean on Task 8 src and test files.
- [x] IMPLEMENTATION-PLAN.md Task 8 acceptance marked `[x]`.
- [x] `tests/Task8*.Tests.ps1` test count: **23** (18 behavior + 5 closure).
