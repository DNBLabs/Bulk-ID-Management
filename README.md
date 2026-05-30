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

Default console output from batch reporting omits passwords and avoids full **UPN** / object IDs. For lab debugging only, a future entry script will support **`-ShowIdentifiers`** (off by default) to print fuller identifiers; do not enable in production transcripts.

## Not Yet Implemented Boundary

CSV import, identity mapping, UPN derivation, certificate Graph auth, fake/real gateway slices, row outcomes, and fake-gateway orchestration are implemented in the module (see [docs/IMPLEMENTATION-PLAN.md](docs/IMPLEMENTATION-PLAN.md)). The public operator entry script, full real-gateway apply, sample CSV, runbook, and lab checklist remain later tasks.
