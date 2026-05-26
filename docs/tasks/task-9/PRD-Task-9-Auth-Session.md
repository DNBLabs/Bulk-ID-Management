# PRD: Task 9 — Authentication Session (Certificate Client Credentials)

## Problem Statement

The real Graph gateway (Task 10) and entry script (Task 13) need an authenticated Microsoft Graph session before making any API calls. Authentication uses the **automation principal** (app registration) with certificate-based client credentials — the only documented auth mode for v1. Without an auth wrapper, every caller would duplicate GUID validation, certificate loading, private-key verification, and `Connect-MgGraph` error handling. Operators need clear, early errors when credentials are wrong, not cryptic MSAL failures deep in the apply path.

## Solution

Implement `Connect-ProvisioningGraph` as a **public** exported function with two mutually exclusive parameter sets (thumbprint vs certificate file path). The function validates all inputs at the boundary, loads certificates when needed, verifies private-key presence, then delegates to `Connect-MgGraph`. On failure, it throws a clear `InvalidOperationException` wrapping the original error. On success, it returns nothing — the Microsoft.Graph SDK session is established globally and subsequent Graph cmdlets use it implicitly.

## User Stories

1. As an operator, I want to connect to Graph with a certificate thumbprint and my app registration IDs, so that I can run apply against my tenant.
2. As an operator, I want to connect to Graph with a PFX file path (and optional password), so that I can authenticate on Linux or in environments without a certificate store.
3. As an operator, I want immediate, clear errors when I supply an invalid tenant ID, client ID, thumbprint format, or certificate path, so that I don't waste time waiting for a network round-trip to fail.
4. As an operator, I want a clear error when my PFX doesn't contain a private key, so that I know to re-export with the private key included.
5. As an operator, I want to connect interactively in a lab session and then run orchestrator commands manually, so that I can debug provisioning row-by-row.
6. As a CI pipeline, I want zero network calls from this function's Pester tests, so that default CI stays offline and credential-free.

## Implementation Decisions

- **Function name and visibility.** `Connect-ProvisioningGraph`, public (exported in manifest and `Export-ModuleMember`). Operators can call it directly for lab debugging.
- **Parameter sets.** Two mutually exclusive sets sharing common mandatory parameters:
  - **Common (both sets):** `-TenantId [string]` (mandatory), `-ClientId [string]` (mandatory).
  - **Thumbprint set:** `-CertificateThumbprint [string]` (mandatory).
  - **CertificatePath set:** `-CertificatePath [string]` (mandatory), `-CertificatePassword [SecureString]` (optional).
- **GUID validation.** `-TenantId` and `-ClientId` validated via `[guid]::TryParse()`. Throw `InvalidOperationException` with clear message if either is not a valid GUID. No env-var fallback — explicit parameters only.
- **Thumbprint validation.** Validated against `^[0-9a-fA-F]{40}$` regex. Catches copy-paste errors, invisible Unicode, partial thumbprints.
- **Certificate path validation.** Check file exists via `Test-Path`. Verify extension is `.pfx` or `.p12` (case-insensitive). PEM not supported in v1.
- **PFX loading.** Load via `[System.Security.Cryptography.X509Certificates.X509Certificate2]::new($path, $password)`. When `-CertificatePassword` is omitted, pass `$null` (unprotected PFX).
- **Private key check.** After loading, verify `$cert.HasPrivateKey` is `$true`. Throw `InvalidOperationException` if missing — "Certificate does not contain a private key."
- **Connect-MgGraph call.** Thumbprint set: `-ClientId`, `-TenantId`, `-CertificateThumbprint`, `-NoWelcome`. Path set: `-ClientId`, `-TenantId`, `-Certificate $cert`, `-NoWelcome`.
- **Error handling.** Wrap all `Connect-MgGraph` failures in `InvalidOperationException` with descriptive message and original as inner exception. Consistent with Tasks 4, 5, 8 error pattern.
- **Return value.** `[void]`. Success = no exception. Caller proceeds with Graph calls.
- **No disconnect wrapper.** Operators use `Disconnect-MgGraph` directly if needed.
- **Idempotency.** Calling `Connect-ProvisioningGraph` a second time replaces the prior session. No pre-check via `Get-MgContext`.
- **Connection scope.** `Connect-MgGraph` establishes a global session in the Microsoft.Graph module. No special scoping by our function.
- **PSScriptAnalyzer.** Function name starts with approved verb `Connect`. No `ShouldProcess` needed — connecting a session is not a state-changing operation on the target system (creating users is, but that's the gateway's job).

## Testing Decisions

- **Mock `Connect-MgGraph`.** Pester tests use `Mock Connect-MgGraph {}` inside `InModuleScope` to prevent network calls. Tests verify parameter forwarding and error handling, not actual Graph auth.
- **Input validation tests.** Cover all boundary checks with bad inputs:
  - Invalid `-TenantId` (not a GUID) → `InvalidOperationException`.
  - Invalid `-ClientId` (not a GUID) → `InvalidOperationException`.
  - Invalid `-CertificateThumbprint` (wrong length, non-hex chars) → `InvalidOperationException`.
  - `-CertificatePath` file does not exist → `InvalidOperationException`.
  - `-CertificatePath` has wrong extension (e.g. `.cer`) → `InvalidOperationException`.
  - Loaded PFX has no private key → `InvalidOperationException`.
- **Success path tests (mocked).** Verify `Connect-MgGraph` is called exactly once with the correct parameters for each set.
- **Connect-MgGraph failure test.** Mock throws; verify our wrapper catches and re-throws `InvalidOperationException` with inner exception.
- **Test files.** `tests/Task9.AuthSession.Tests.ps1` — all behavior tests. `tests/Task9.Closure.Tests.ps1` — smoke, plan checkboxes, PSScriptAnalyzer, scope guard.
- **CI safety.** All tests run with mocked `Connect-MgGraph`. No Microsoft.Graph import needed in tests (mock replaces the command). CI remains Graph-free.

## Out of Scope

- **Task 10+ (real gateway, orchestrator, entry script).** Task lock: Task 9 only.
- **Client secret auth.** Not the default documented path per CONTEXT.
- **Delegated / device code auth.** Out of scope for v1.
- **PEM certificate format.** Operators convert to PFX via `openssl pkcs12 -export`.
- **Environment variable fallback.** Entry script (Task 13) may wire env vars to its own parameters.
- **Disconnect wrapper.** `Disconnect-MgGraph` used directly.
- **Certificate renewal or rotation.** Operational concern, not automation scope.

## Further Notes

- The existing `FunctionsToExport` in `BulkIdentityManagement.psd1` and `Export-ModuleMember` in `.psm1` must be updated to include `Connect-ProvisioningGraph`.
- Task 9 depends on Task 1 (manifest with pinned Microsoft.Graph). No dependency on Tasks 3-8.
- The real gateway (Task 10) assumes `Connect-ProvisioningGraph` has been called before it invokes Graph cmdlets. The entry script (Task 13) enforces this ordering.
