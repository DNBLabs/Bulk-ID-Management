# Plan: Task 7 — Graph Gateway Contract (narrow interface)

**Parent:** [IMPLEMENTATION-PLAN.md](../../IMPLEMENTATION-PLAN.md) Task 7.
**Normative:** [CONTEXT.md](../../../CONTEXT.md) — Graph gateway contract shape, operations, builders.

## Goal

Define the minimal set of Graph operations the orchestrator consumes via a
hashtable-of-ScriptBlocks contract. Deliver `New-FakeProvisioningGraphGateway`
as a private stub whose entries throw `NotImplementedException` (Task 8 fills
in real fake logic; Task 10 provides a live Graph builder).

## Sub-tasks

- [x] **A — Stub builder function** — Private `New-FakeProvisioningGraphGateway` returns a hashtable with six ScriptBlock entries (TestUpnExists, NewUser, UpdateUser, GetGroupById, TestGroupMembership, AddGroupMember), each throwing `NotImplementedException`.
- [x] **B — Contract shape tests** — `Task7.GatewayContract.Tests.ps1`: hashtable type, six keys, ScriptBlock values, each throws on invocation (9 tests).
- [x] **C — Closure** — `Task7.Closure.Tests.ps1`: smoke, plan checkboxes, PSScriptAnalyzer clean, no Task 8+ test files, scope guard.

## Checkpoint

- [x] All `tests/Task7*.Tests.ps1` pass.
- [x] PSScriptAnalyzer clean on Task 7 src.
- [x] IMPLEMENTATION-PLAN.md Task 7 acceptance marked `[x]`.
- [x] `tests/Task7*.Tests.ps1` test count: **14** (9 contract + 5 closure).
