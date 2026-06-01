# Operator runbook: bulk provisioning

Normative contract: [CONTEXT.md](../CONTEXT.md) at the repository root. This runbook is procedural guidance for a lab or production tenant; it does not override CONTEXT.

## Prerequisites

1. **PowerShell 7** (`pwsh`), 7.4+ preferred (see README).
2. **Automation principal** (app registration) with **application** permissions and **admin consent**:
   - `User.ReadWrite.All`
   - `Group.Read.All`
   - `GroupMember.ReadWrite.All`
3. **Certificate** for client-credentials auth installed on the operator machine (private key and `.pfx` **outside** the repository). Note the **certificate thumbprint**, **tenant ID**, and **client ID** (app ID).
4. **IT membership group** already exists in Entra. Obtain the group **Object ID** (GUID) and pass it as `-ItMembershipGroupId`.
5. **Verified domain** for UPN suffix (e.g. `contoso.com`) matching `-TenantDomainSuffix`.
6. A provisioning CSV in [CONTEXT](../CONTEXT.md) **Provisioning CSV format**. Use the committed sample: [samples/provisioning-sample.csv](../samples/provisioning-sample.csv) (fictional names only; no tenant identifiers).

## Certificate placement

Store the `.pfx` (or cert + key) in a path your org controls (e.g. `%USERPROFILE%\certs\provisioning-automation.pfx`). Import to `CurrentUser\My` or `LocalMachine\My` so the thumbprint is visible to `Get-ChildItem Cert:\CurrentUser\My`. Do not commit certificate material to git.

## Dry run (required before apply)

Dry run connects to Graph as the automation principal but **does not** create users, set passwords, or add group members. Review the per-row plan before mutating apply.

From the repository root:

```powershell
pwsh ./src/Scripts/Invoke-BulkIdentityProvisioning.ps1 `
  -CsvPath ./samples/provisioning-sample.csv `
  -TenantId '<tenant-guid>' `
  -ClientId '<app-guid>' `
  -CertificateThumbprint '<40-char-hex-thumbprint>' `
  -TenantDomainSuffix 'contoso.com' `
  -ItMembershipGroupId '<it-group-object-id-guid>' `
  -DryRun
```

`-WhatIf` is equivalent to `-DryRun` for this entry point.

## Apply (mutating)

After dry-run output looks correct, run the same command **without** `-DryRun` / `-WhatIf`.

Optional flags:

| Flag | Purpose |
|------|---------|
| `-UpdateExisting` | Update **only** `department`, `givenName`, `surname`, `displayName` when UPN already exists (see CONTEXT **Re-run behavior**). |
| `-UsageLocation` | ISO 3166 alpha-2 (e.g. `US`) on **newly created** users only. |
| `-ItDepartmentTarget` | Department value that triggers IT group membership (default `IT`). |
| `-ShowIdentifiers` | Lab debugging: fuller UPN/object IDs in output (off by default). |

**Apply output may be sensitive** (passwords for new users are not written to default console output; do not enable `-ShowIdentifiers` in production transcripts).

## Interpreting row outcomes

Each row produces a **row outcome** label:

| Status | Meaning |
|--------|---------|
| **Created** | New user created for this row. |
| **Skipped** | UPN already exists; user creation skipped (default re-run). |
| **Updated** | Existing user updated (`-UpdateExisting` and allowed attributes). |
| **MembershipEnsured** | IT rule matched; user is a member of the IT group (or already was). |
| **Failed** | Row failed; see reason text. Other rows may still process. |

The script prints an aggregate summary, then returns a result object. The operator script exits with `$result.ExitCode`.

## Batch error policy and exit code

Per CONTEXT **batch error policy**:

- One row **Failed** does **not** stop remaining rows.
- The run **exits non-zero** if **any** row has status **Failed** (`ExitCode` **1**).
- When all rows succeed (Created, Skipped, Updated, MembershipEnsured), `ExitCode` is **0**.

Use `$LASTEXITCODE` after the script in automation wrappers. Investigate failed rows in the aggregate report before re-running apply.

## Sample CSV

[samples/provisioning-sample.csv](../samples/provisioning-sample.csv) uses only **FirstName**, **LastName**, and **Department** (v1 minimal shape). Optional override columns documented in CONTEXT are not required for the sample.

## Further reading

- [README.md](../README.md) — CI vs apply, credential safety
- [docs/lab-integration-checklist.md](lab-integration-checklist.md) — human verification in a dev tenant (non-CI)
- [docs/Design/SEC.md](Design/SEC.md) — permissions and secret handling
