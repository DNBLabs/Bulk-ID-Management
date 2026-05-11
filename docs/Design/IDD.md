# Infrastructure Design Document: Bulk Identity Management

**Normative glossary and behavioral contract:** [CONTEXT.md](../CONTEXT.md). **Architecture narrative:** [HLD.md](HLD.md). If this IDD conflicts with CONTEXT, CONTEXT prevails.

**Scope:** Governance blueprint for Infrastructure as Code that will eventually support the automation principal (Microsoft Entra app registration / service principal), GitHub Actions federated workload identity (OIDC), optional GitHub Environment for tenant-mutating workflows, and a secured Terraform remote state footprint. This document does **not** include Terraform `.tf` source. User bulk provisioning continues to be performed by PowerShell against Microsoft Graph per CONTEXT; IaC covers **identity and platform objects** implied by the repository contract, not per-row directory users.

**Secrets and identifiers:** No secrets, tenant IDs, client IDs, subscription IDs, or certificate private key material are hardcoded in Terraform state, committed variable defaults, or module defaults. Values are supplied at plan/apply time via non-committed `*.tfvars`, pipeline-injected environment variables, or secret stores aligned with organizational policy.

---

## A. Resource Governance (Naming & Tagging)

### Naming convention formula

**Default (Azure Resource Manager resources):**

`<CompanyCode>-<ProjectCode>-<Environment>-<AzureRegion>-<ServiceType>-<InstancePadding>`

- **CompanyCode:** Short alphabetic firm code (lowercase), 2–6 characters.
- **ProjectCode:** Short project slug for this repository (e.g. `bulkid`), lowercase, 4–12 characters.
- **Environment:** `dev` | `test` | `prod` (or organization-standard equivalents).
- **AzureRegion:** Azure region token without spaces (e.g. `eastus2`). Omit only where the resource type is global and the platform forbids region in the name; then substitute `global` in the same segment position for human-readable names only, not for resource types that require a region.
- **ServiceType:** Short role token (e.g. `rg`, `st`, `uai`). Use `rg-terraform` for bootstrap resource groups, `st-tfstate` for state storage accounts.
- **InstancePadding:** Two-digit instance (`01`, `02`) to allow parallel stacks or blue/green bootstrap.

**Derived naming (storage account):** Azure storage account names must be globally unique, 3–24 characters, lowercase alphanumeric only. Apply a documented abbreviation: `st` + `<CompanyCode>` + `<ProjectCode>` + `<Environment>` + optional disambiguator, truncated or hashed per enterprise runbook to satisfy length and uniqueness (example pattern: `stcorpbulkidprod01`).

**Microsoft Entra directory objects (display names):** Use the same semantic segments in a display name suitable for audit (`<CompanyCode>-<ProjectCode>-<Environment>-sp-graph-automation`). Entra object identifiers (object IDs, application IDs) are assigned by the directory and are not embedded in naming formulas.

### Examples (concrete)

| Example | Applied naming string | Resource type |
|--------|------------------------|---------------|
| 1 | `corp-bulkid-prod-eastus2-rg-terraform-01` | Azure Resource Group hosting Terraform remote state and related platform resources |
| 2 | `stcorpbulkidprod01` | Azure Storage Account (remote state blob backend), following abbreviated storage naming rules |
| 3 | `corp-bulkid-prod-sp-graph-automation` | Microsoft Entra app registration **display name** for the automation principal used with Microsoft Graph |

### Mandatory tags matrix

Every Azure resource created or managed by this IaC program SHALL carry the following tags unless a resource type does not support tags (tag inheritance or policy-based alternatives apply where supported).

| Tag name | Description | Example value |
|----------|-------------|---------------|
| `Environment` | Deployment lifecycle | `prod` |
| `Owner` | Responsible team or DL | `identity-ops@example.com` |
| `CostCenter` | Financial chargeback code | `CC-4491` |
| `ManagedBy` | Provisioning tool | `terraform` |
| `Project` | Logical project | `bulk-id-management` |
| `DataClassification` | Sensitivity of data the resource may touch | `Confidential` (state and identity surfaces) |
| `Repo` | Source repository identifier | `bulk-id-management` (or org/repo path per standard) |

---

## B. Remote State & Bootstrapping Strategy

### The bootstrap process

Terraform cannot create its own remote backend container in a single plan without a chicken-and-egg problem. Execute bootstrap in this order:

1. **Subscription context:** An administrator selects the target Azure subscription (identifier supplied at runtime, not hardcoded in committed Terraform). Role assignments grant the bootstrap principal least privilege to create only the bootstrap resource group and storage.

2. **Bootstrap resource group:** Create `corp-bulkid-prod-eastus2-rg-terraform-01` (or environment-specific equivalent) in the chosen region. This group holds state storage and optional companion resources (diagnostics, private endpoint subnets if adopted).

3. **Bootstrap storage account:** Create the abbreviated storage account name per Section A. Enable hierarchical namespace only if required by broader policy; default is standard blob for `tfstate`. Create a dedicated blob container (e.g. `tfstate`) for Terraform state blobs.

4. **Backend configuration:** Configure the root module backend to `azurerm` pointing at the subscription, resource group, storage account, and container. Run `terraform init -migrate-state` once from any secure operator context to migrate local state to remote, or initialize directly against remote for greenfield.

5. **Downstream modules:** Application of `azuread` and optional `github` provider resources proceeds only after remote backend is healthy, state locking verified, and RBAC on the state blob scope is confirmed.

### State security

| Control | Requirement |
|---------|-------------|
| **Encryption at rest** | Storage account infrastructure encryption enabled; Microsoft-managed keys acceptable minimum; customer-managed keys via Key Vault optional per organizational crypto standard. |
| **Network access** | Default deny public network access where policy allows; prefer private endpoints for blob from approved networks. CI agents that must run `terraform plan` use organization-approved runners and network paths. No `0.0.0.0/0` exposure for data-plane access to state blobs. |
| **RBAC** | State container scoped to least privilege: separate roles for humans (read/plan), automation (plan-only vs apply), and emergency break-glass. No wildcard `*` on actions at subscription scope for routine principals. |
| **State locking** | Enable blob leasing for Terraform state; concurrent applies blocked by lock. Fail closed on lock acquisition timeout. |
| **Soft delete / versioning** | Enable blob soft delete and versioning on the state container where supported to support controlled recovery from accidental overwrite. |
| **Audit** | Diagnostic settings forward storage account control-plane and data-plane audit events to the organization’s central logging workspace when required by policy. |

---

## C. Infrastructure Provisioning Matrix

| Logical Component | Cloud Service | Terraform Resource | Enterprise Config Notes |
|-------------------|---------------|----------------------|-------------------------|
| Terraform state resource group | Azure Resource Manager — Resource Group | `azurerm_resource_group` | Name per Section A tags; lock resource group optionally with `CanNotDelete` after stabilization. |
| Terraform state storage | Azure Storage — Storage Account | `azurerm_storage_account` | TLS 1.2+ only; public access disabled for blobs at account level; SAS/token auth avoided for Terraform in favor of RBAC + managed identity or OIDC-fed pipeline identity where applicable; minimum TLS and secure transfer required. |
| Terraform state container | Azure Storage — Blob Container | `azurerm_storage_container` | Private access; dedicated container `tfstate` (or standard name); versioning/soft delete per Section B. |
| Automation principal (directory application) | Microsoft Entra ID — App registration | `azuread_application` | Display name per Section A; sign-in audience appropriate for single-tenant; **no** client secret generated in code as default path; owners assigned per IAM runbook. |
| Automation service principal | Microsoft Entra ID — Enterprise application / SP | `azuread_service_principal` | Linked to `azuread_application`; notes attribute for operations contact. |
| GitHub Actions OIDC federation | Microsoft Entra ID — Federated identity credential | `azuread_application_federated_identity_credential` | Issuer `https://token.actions.githubusercontent.com`; subject constrained to repository and environment or ref pattern per least privilege; no broad `repo:*` subject without exception approval. |
| Graph application permissions (declarative) | Microsoft Graph — Application permissions | `azuread_application` (`required_resource_access`) and/or `azuread_app_role_assignment` / `azuread_service_principal` permission resources per provider version | Least privilege per CONTEXT: **`User.ReadWrite.All`**, **`Group.Read.All`**, **`GroupMember.ReadWrite.All`** only; **`Directory.ReadWrite.All`** not used as default; admin consent tracked outside Terraform or via controlled break-glass process. |
| Optional tenant-mutate approval gate | GitHub — Environment | `github_repository_environment` (GitHub Terraform provider) | Environment name aligned with CONTEXT (e.g. `entra-apply`); `required_reviewers` configured; deployment branch policy restricted; secrets if any held as GitHub encrypted secrets, not in Terraform state plaintext. |
| IT membership target group | Microsoft Entra ID — Group | *Not provisioned in v1 per CONTEXT* | Group is **pre-created** by administrator; automation resolves by **Object ID** at apply time. If future IaC imports the group, use `azuread_group` with import workflow and document drift ownership. |
