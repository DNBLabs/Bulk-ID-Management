# Plan: Task 10 — Real Graph Gateway + Graph Transient Policy



**Parent:** [IMPLEMENTATION-PLAN.md](../../IMPLEMENTATION-PLAN.md) Task 10.

**PRD:** [PRD-Task-10-Real-Graph-Gateway.md](PRD-Task-10-Real-Graph-Gateway.md).

**Normative:** [CONTEXT.md](../../../CONTEXT.md) — Real graph gateway (Task 10 resolved decisions).



**Scope lock:** This plan decomposes **Implementation Plan Task 10** only. It does **not** include row outcomes/reporting (Task 11), orchestrator (Task 12), entry script (Task 13), or changes to the fake gateway beyond contract-test compatibility.



## Goal



Implement **`New-ProvisioningGraphGateway`** and supporting private helpers so the Task 7

contract is satisfied against live **Microsoft.Graph v1.0** cmdlets with bounded

**graph transient policy** and stable **`InvalidOperationException`** errors. All CI

tests mock Graph cmdlets; no network in default pipelines.



## Sub-tasks



### Phase 1: Scaffold + retry wrapper (tracer bullet)



- [x] **A — Private helper files and psm1 wiring.** Add `Invoke-ProvisioningGraphCommand.ps1` (retry + wrap) and skeleton `New-ProvisioningGraphGateway.ps1`. Dot-source from `BulkIdentityManagement.psm1`. Constants for max attempts (5), base delay (2s), cumulative cap (90s), retryable status codes.

- [x] **B — Tracer bullet: wrapper retries 429 then succeeds.** Pester test mocks a script block that throws 429 once then succeeds; assert two invocations and success. Red-green.



### Phase 2: Retry policy + error wrapping



- [x] **C — Non-retryable errors fail fast.** Test: mock throws 403; wrapper invoked once; `InvalidOperationException` with inner preserved.

- [x] **D — Exhausted retries.** Test: mock always throws 429; assert attempt count ≤ 5 and final `InvalidOperationException` prefix `Graph` (or operation name passed to wrapper).

- [x] **E — Retry-After honored.** Test: mock 429 with `Retry-After` header/metadata; assert delay behavior within cap (use minimal delays or inject clock if needed; document test approach).

- [x] **F — Cumulative wait cap.** Test: scenario that would exceed 90s total wait is cut off (mock or parameter injection).



### Phase 3: Builder + profile



- [x] **G — `New-ProvisioningGraphGateway` scaffold.** Parameterless; calls `Select-MgProfile -Name 'v1.0'` (mocked in tests); returns hashtable with six ScriptBlock keys (stubs calling wrapper). — `New-ProvisioningGraphGateway.ps1`; `Task10.Phase3.RealGatewayBuilder.Tests.ps1`.

- [x] **H — Profile failure.** Test: `Select-MgProfile` throws → builder throws clear `InvalidOperationException`. — Same test file, profile failure `It` block.

- [x] **H-security — Phase 3 security tests.** `Task10.Phase3.RealGatewayBuilder.Security.Tests.ps1` (8 tests): private/not exported, v1.0-only profile, no GUID/secrets in source, sanitized profile error outer message.

- [x] **U — Phase 3 closure + IMPLEMENTATION-PLAN slice.** `Task10.Phase3.Closure.Tests.ps1`; Phase lock [3] checklist in IMPLEMENTATION-PLAN Phase 3 section.



### Phase 4: Shared helpers



- [x] **I — Property key normalization.** Private helper maps PascalCase/camelCase to camelCase for allowed keys; rejects unknown keys for `UpdateUser`; tests for both casings.

- [x] **J — OData UPN escape.** Private helper escapes `'` and rejects control chars; unit tests including `o'brien@contoso.com`.

- [x] **K — Password generation.** Private helper: 32-char mixed-class password as `SecureString`; test length/charset classes without inspecting secret value in output.



### Phase 5: Gateway operations (mocked cmdlets)



- [x] **L — `TestUpnExists`.** Filter lookup; 0 → `$null`, 1 → id, 2+ → throw. Mock `Get-MgUser`. Tests for each path + OData escape invoked.

- [x] **M — `NewUser`.** Mock `New-MgUser`; assert mapped fields, `accountEnabled`, `forceChangePasswordNextSignIn`, password parameter present (SecureString), returns id. No password in logs/messages.

- [x] **N — `UpdateUser`.** Mock `Update-MgUser`; allowed four fields; extra key throws before mock invoked.

- [x] **O — `GetGroupById`.** GUID validation; mock `Get-MgGroup`; not found throws.

- [x] **P — `TestGroupMembership`.** GUID validation; mock `Get-MgGroupMember` filter; `$true`/`$false`.

- [x] **Q — `AddGroupMember`.** Mock `TestGroupMembership` path via member query or test idempotent branch: when membership true, `New-MgGroupMember` not called.



### Phase 6: Closure + plan update



- [x] **R — Security tests.** `Task10.RealGateway.Security.Tests.ps1`: no password in exception text; OData injection-safe filter; GUID validation on ids.

- [x] **S — Closure.** `Task10.Closure.Tests.ps1`: builder smoke (6 keys, ScriptBlocks), PSScriptAnalyzer clean, scope guard (no Task 11+ files), plan file exists.

- [x] **T — Update IMPLEMENTATION-PLAN.md.** Mark Task 10 acceptance/verification `[x]` with test counts and manual lab note when complete.



## Checkpoint



- [x] All `tests/Task10.Phase3*.Tests.ps1` pass (Phase 3 lock only).

- [x] All `tests/Task10*.Tests.ps1` pass (full Task 10).

- [x] Full Pester suite green (as of Task 10 completion).

- [x] PSScriptAnalyzer clean on Task 10 Phase 3 src and test files.

- [x] `New-ProvisioningGraphGateway` is **not** in `FunctionsToExport` (private only).

- [x] No live Graph calls in any Task 10 Phase 3 test (cmdlets mocked).

- [x] IMPLEMENTATION-PLAN.md Task 10 acceptance criteria satisfied (full task):

  - [x] No beta profile by default (`Select-MgProfile v1.0`) — Phase 3 builder slice.

  - [x] Retries capped (attempt count + cumulative wait).

  - [x] IT membership group resolved by Object ID only.

- [x] Manual lab smoke documented (optional until app permissions granted): connect → `New-ProvisioningGraphGateway` → `TestUpnExists` / small operation. — Covered by 2026-05-31 Task 13 lab path through full entry script and CSV apply.



## Dependencies



| Depends on | Reason |

|------------|--------|

| Task 7 | Contract shape (six ScriptBlocks) |

| Task 9 | `Connect-ProvisioningGraph` before builder |

| Task 1 | Pinned `Microsoft.Graph` module |



| Blocks | Reason |

|--------|--------|

| Task 12 | Orchestrator needs real gateway for apply |

| Task 13 | Entry script wires auth + gateway |

