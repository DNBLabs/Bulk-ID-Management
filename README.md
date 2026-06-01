# Bulk Identity Management

[CONTEXT.md](CONTEXT.md) is the normative glossary and behavioral contract for this repository.

This README is a landing page for the project documents. `CONTEXT.md` wins on conflicts with this README, design documents, plans, or the informal background brief.

## Documentation Map

- Product requirements: [docs/PRD.md](docs/PRD.md)
- Architecture design: [docs/Design/HLD.md](docs/Design/HLD.md)
- Infrastructure design: [docs/Design/IDD.md](docs/Design/IDD.md)
- Security and compliance profile: [docs/Design/SEC.md](docs/Design/SEC.md)
- Implementation task order: [docs/IMPLEMENTATION-PLAN.md](docs/IMPLEMENTATION-PLAN.md)
- Operator runbook: [docs/runbook.md](docs/runbook.md)
- Lab integration checklist (non-CI): [docs/lab-integration-checklist.md](docs/lab-integration-checklist.md)
- Background only, not a behavioral contract: [docs/init-project.txt](docs/init-project.txt)

## CI Scope vs Apply Path

CI scope is validate-only: default CI validation gates run local checks such as PSScriptAnalyzer and Pester, and default CI does not call Microsoft Graph or create/change Entra tenant objects.

Tenant mutation belongs to the explicit apply path, primarily from a local or controlled runner using documented authentication. Operators must perform dry-run before mutating apply so the plan can be reviewed before any directory changes.

### Default CI (local or GitHub)

From the repository root with **PowerShell 7** (`pwsh`):

```powershell
./.github/scripts/Invoke-PSScriptAnalyzerCI.ps1
Invoke-Pester -Path ./tests -CI
./.github/scripts/Invoke-ModuleManifestCI.ps1
```

GitHub Actions runs the same gates in [`.github/workflows/ci.yml`](.github/workflows/ci.yml) on `push` and `pull_request` to `main`. PSScriptAnalyzer fails the build on **Error** and **Warning** severities for `.ps1` / `.psm1` under `src`, `tests`, and `.github/scripts`.

### Optional manual apply workflow (template)

A separate, tenant-mutating workflow template lives at [`.github/workflows/apply-dispatch-placeholder.yml`](.github/workflows/apply-dispatch-placeholder.yml). It is triggered only by **`workflow_dispatch`**, targets the **`entra-apply`** GitHub Environment (configure **required reviewers**), and is not part of default PR validation.

Register the automation principal federated credential with OIDC subject `repo:<GitHubOrg>/<GitHubRepo>:environment:entra-apply` per [docs/Design/SEC.md](docs/Design/SEC.md). Replace the placeholder job with provisioning entry wiring when GitHub-hosted apply is required.

## Credential Safety

Local apply authentication uses certificate-based client credentials for the automation principal. Certificate material and private key material stay outside the repository, and a client secret is not the default path.

## Current Implementation Status

v1 implementation tasks (foundation through lab hardening) are complete per [docs/IMPLEMENTATION-PLAN.md](docs/IMPLEMENTATION-PLAN.md). The `BulkIdentityManagement` module lives under `src/Modules/BulkIdentityManagement/`, targets PowerShell 7.2+ with 7.4+ preferred, and pins `Microsoft.Graph` through the repository module manifest.

Committed sample data: [samples/provisioning-sample.csv](samples/provisioning-sample.csv). Step-by-step tenant work: [docs/runbook.md](docs/runbook.md).

## Apply output hygiene

Default console output from batch reporting omits passwords and avoids full **UPN** / object IDs. For lab debugging only, **`-ShowIdentifiers`** (off by default) prints fuller identifiers; do not enable in production transcripts.

## Operator entry

Dry-run before mutating apply. Full prerequisites, dry-run and apply commands, row outcomes, and **batch error policy** exit semantics: [docs/runbook.md](docs/runbook.md).

Entry script: `src/Scripts/Invoke-BulkIdentityProvisioning.ps1` (or **`Invoke-BulkIdentityProvisioning`** after `Import-Module`). Human lab verification: [docs/lab-integration-checklist.md](docs/lab-integration-checklist.md).

The optional GitHub apply workflow remains a **placeholder** until `entra-apply` environment secrets and OIDC are configured (see CI section above).
