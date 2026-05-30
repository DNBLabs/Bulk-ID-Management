# Bulk Identity Management

[CONTEXT.md](CONTEXT.md) is the normative glossary and behavioral contract for this repository.

This README is a landing page for the project documents. `CONTEXT.md` wins on conflicts with this README, design documents, plans, or the informal background brief.

## Documentation Map

- Product requirements: [docs/PRD.md](docs/PRD.md)
- Architecture design: [docs/Design/HLD.md](docs/Design/HLD.md)
- Infrastructure design: [docs/Design/IDD.md](docs/Design/IDD.md)
- Security and compliance profile: [docs/Design/SEC.md](docs/Design/SEC.md)
- Implementation task order: [docs/IMPLEMENTATION-PLAN.md](docs/IMPLEMENTATION-PLAN.md)
- Background only, not a behavioral contract: [docs/init-project.txt](docs/init-project.txt)

## CI Scope vs Apply Path

CI scope is validate-only: default CI validation gates run local checks such as PSScriptAnalyzer and Pester, and default CI does not call Microsoft Graph or create/change Entra tenant objects.

Tenant mutation belongs to the explicit apply path, primarily from a local or controlled runner using documented authentication. Operators must perform dry-run before mutating apply so the plan can be reviewed before any directory changes.

## Credential Safety

Local apply authentication uses certificate-based client credentials for the automation principal. Certificate material and private key material stay outside the repository, and a client secret is not the default path.

## Current Implementation Status

Implementation is in progress; see [docs/IMPLEMENTATION-PLAN.md](docs/IMPLEMENTATION-PLAN.md) for task status.

The Task 1 foundation is present: the `BulkIdentityManagement` module scaffold lives under `src/Modules/BulkIdentityManagement/`, targets PowerShell 7.2+ with 7.4+ preferred, and pins `Microsoft.Graph` through the repository module manifest rather than a floating dependency policy.

## Apply output hygiene

Default console output from batch reporting omits passwords and avoids full **UPN** / object IDs. For lab debugging only, **`-ShowIdentifiers`** (off by default) prints fuller identifiers; do not enable in production transcripts.

## Operator entry (Task 13)

Dry-run before mutating apply: review the plan with **`-DryRun`** or **`-WhatIf`** before running apply without those switches. Dry-run still calls **`Connect-ProvisioningGraph`** (certificate auth to the automation principal); only directory mutations are suppressed.

From the repository root (after placing a provisioning CSV and certificate credentials outside the repo):

```powershell
pwsh ./src/Scripts/Invoke-BulkIdentityProvisioning.ps1 `
  -CsvPath ./path/to/users.csv `
  -TenantId '<tenant-guid>' `
  -ClientId '<app-guid>' `
  -CertificateThumbprint '<40-char-hex-thumbprint>' `
  -TenantDomainSuffix 'contoso.com' `
  -ItMembershipGroupId '<it-group-object-id-guid>' `
  -DryRun
```

Optional flags: **`-UpdateExisting`**, **`-UsageLocation`** (ISO alpha-2 for new users), **`-ItDepartmentTarget`** (default `IT`), **`-ShowIdentifiers`**. The script exits with a non-zero code when any row failed (**batch error policy**).

The same surface is available after `Import-Module` as **`Invoke-BulkIdentityProvisioning`**.

## Not Yet Implemented Boundary

Sample CSV, full runbook, optional GitHub apply workflow template, and lab integration checklist remain later tasks (see [docs/IMPLEMENTATION-PLAN.md](docs/IMPLEMENTATION-PLAN.md)).
