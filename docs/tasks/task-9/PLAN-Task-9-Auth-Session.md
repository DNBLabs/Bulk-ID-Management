# Plan: Task 9 — Authentication Session (Certificate Client Credentials)

**Parent:** [IMPLEMENTATION-PLAN.md](../../IMPLEMENTATION-PLAN.md) Task 9.
**PRD:** [PRD-Task-9-Auth-Session.md](PRD-Task-9-Auth-Session.md).
**Normative:** [CONTEXT.md](../../../CONTEXT.md) — Authentication session API.

## Goal

Implement `Connect-ProvisioningGraph` as a public exported function with two
parameter sets (thumbprint vs PFX file path), strict input validation at the
boundary, and clear error wrapping around `Connect-MgGraph`. All Pester tests
mock `Connect-MgGraph` to keep CI Graph-free.

## Sub-tasks

### Phase 1: Scaffold + tracer bullet

- [x] **A — Create source file and register in module.** Add `src/Modules/BulkIdentityManagement/Public/Connect-ProvisioningGraph.ps1` with function skeleton (CmdletBinding, parameter sets, OutputType void). Update `FunctionsToExport` in `.psd1` and `Export-ModuleMember` in `.psm1`. Verify module loads.
- [x] **B — Tracer bullet: thumbprint happy path (mocked).** First Pester test: mock `Connect-MgGraph`, call `Connect-ProvisioningGraph` with valid GUIDs + valid thumbprint, assert `Connect-MgGraph` called once with correct params. Red-green.

### Phase 2: Input validation

- [x] **C — TenantId GUID validation.** `[guid]::TryParse()` check. Test: non-GUID string throws `InvalidOperationException`.
- [x] **D — ClientId GUID validation.** Same pattern. Test: non-GUID string throws `InvalidOperationException`.
- [x] **E — Thumbprint format validation.** Regex `^[0-9a-fA-F]{40}$`. Tests: too short, non-hex chars, correct 40-char hex passes.
- [x] **F — CertificatePath existence check.** `Test-Path` for file. Test: non-existent path throws `InvalidOperationException`.
- [x] **G — CertificatePath extension check.** `.pfx`/`.p12` case-insensitive. Test: `.cer` extension throws `InvalidOperationException`.

### Phase 3: PFX loading and Connect-MgGraph wiring

- [x] **H — PFX loading + private key check.** Load X509Certificate2, verify `HasPrivateKey`. Test: mock cert load or use test fixture; missing private key throws `InvalidOperationException`.
- [x] **I — CertificatePath happy path (mocked).** Mock `Connect-MgGraph`, call with valid path + PFX fixture, assert `Connect-MgGraph` called with `-Certificate` parameter. Red-green.
- [x] **J — Connect-MgGraph failure wrapping.** Mock `Connect-MgGraph` to throw. Test: our function catches and re-throws `InvalidOperationException` with inner exception preserved.

### Phase 4: Closure

- [x] **K — Closure tests.** `Task9.Closure.Tests.ps1`: smoke test (function exists), plan checkboxes marked, PSScriptAnalyzer clean on new files, scope guard (no Task 10+ files).
- [x] **L — Update IMPLEMENTATION-PLAN.md.** Mark Task 9 acceptance and verification checkboxes `[x]`.

## Checkpoint

- [x] All `tests/Task9*.Tests.ps1` pass.
- [x] Full Pester suite green.
- [x] PSScriptAnalyzer clean on Task 9 src and test files.
- [x] `Connect-ProvisioningGraph` appears in `FunctionsToExport` and `Export-ModuleMember`.
- [x] IMPLEMENTATION-PLAN.md Task 9 acceptance marked `[x]`.
- [x] No `Connect-MgGraph` calls reach the network in any test.
- [x] `tests/Task9*.Tests.ps1` test count: **25** (11 behavior + 9 security + 5 closure).
- [x] Prior export tests updated to include `Connect-ProvisioningGraph` (Tasks 1, 3).
