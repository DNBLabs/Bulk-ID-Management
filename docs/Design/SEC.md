# Security & Compliance Profile: Bulk Identity Management

**Normative glossary and behavioral contract:** [CONTEXT.md](../CONTEXT.md). Supporting architecture: [HLD.md](HLD.md), [IDD.md](IDD.md). If this profile conflicts with CONTEXT, CONTEXT prevails.

**Posture:** Zero-trust assumptions on all inputs; least-privilege directory and cloud roles; shift-left validation in default CI. **Forbidden:** Long-lived client secrets, access keys, or static passwords for the **automation principal** or **CI credential** paths described in CONTEXT. Certificate private keys and any future signing material SHALL NOT be committed to the repository.

---

## A. Identity & Access Management (OIDC & RBAC)

### OIDC subject mapping (GitHub Actions → Microsoft Entra federated credential)

Federated identity credentials on the **automation principal** SHALL bind to **exact** GitHub OIDC subjects. Use **one credential per subject pattern**; do not use unconstrained wildcards.

| Credential purpose | Required `issuer` | Required `subject` format |
|--------------------|--------------------|---------------------------|
| Branch-scoped automation (example: `main` only) | `https://token.actions.githubusercontent.com` | `repo:<GitHubOrg>/<GitHubRepo>:ref:refs/heads/main` |
| Tag/release-scoped automation (if used) | `https://token.actions.githubusercontent.com` | `repo:<GitHubOrg>/<GitHubRepo>:ref:refs/tags/<tagname>` |
| Manual tenant-mutating workflow (CONTEXT: optional apply path) | `https://token.actions.githubusercontent.com` | `repo:<GitHubOrg>/<GitHubRepo>:environment:entra-apply` |

Replace `<GitHubOrg>/<GitHubRepo>` with the canonical repository slug. If both branch and environment workflows require Azure AD workload authentication, register **separate** federated credentials with **non-overlapping** subjects. **Pull-request** subjects (for example `repo:ORG/REPO:pull_request`) SHALL NOT be used for credentials that can obtain tokens capable of **mutating** Entra ID unless explicitly approved by security architecture; default CI does not call Graph.

### Role-based access control (RBAC)

**Microsoft Entra — application permissions (automation principal)**  
Grant **application** permissions only, with **admin consent**, to the minimum set defined in CONTEXT: **`User.ReadWrite.All`**, **`Group.Read.All`**, **`GroupMember.ReadWrite.All`**. Do **not** grant **`Directory.ReadWrite.All`** as a default. **Delegated** permissions and **device-code** interactive paths are **out of scope for v1** per CONTEXT; do not mix permission models with application-only apply.

**Microsoft Entra — credential policy**  
Primary CI authentication: **federated workload identity (OIDC)** from GitHub Actions to the app registration—**no** repository-stored client secret for CI. Local or self-hosted apply: **certificate-based client credentials**; private key and certificate file **outside** the repository. **Client secret** is **not** the default documented path.

**Azure Resource Manager (only if CI or approved workflows run Terraform or touch Azure resources)**  
Default validate-only workflows in CONTEXT do **not** require subscription RBAC for Microsoft Graph. When Azure is in play (for example remote state or `azuread` provider execution from a pipeline):

| Identity | Allowed scope | Maximum privilege role / action |
|----------|----------------|----------------------------------|
| GitHub OIDC workload identity used for **Terraform plan** (read-only) | Single resource group containing Terraform state (and read-only data sources as designed) | **Reader** on that resource group **or** custom role limited to `Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read` and supporting read metadata—**not** subscription **Contributor**. |
| GitHub OIDC workload identity used for **Terraform apply** (after environment approval) | Same target resource group(s) defined in IDD for identity/automation infrastructure | **Contributor** on **that** resource group **only**—never subscription-wide **Contributor** or **Owner** as the standing assignment. |
| Human operators | Per jump/access policy | **Owner** / **User Access Administrator** only through PIM or equivalent break-glass; not granted to pipeline identities. |

**GitHub repository**  
Default workflows require only the minimum `GITHUB_TOKEN` permissions for checkout and artifact policies defined by org. Tenant-mutating workflows SHALL target the **`entra-apply`** (or equivalent) **GitHub Environment** with **required reviewers** so OIDC-backed jobs cannot obtain approval-authenticated tokens without human gate.

---

## B. DevSecOps Pipeline Gates

### Static analysis and tests (mandatory — CONTEXT)

| Gate | Break-the-build rule |
|------|----------------------|
| **PSScriptAnalyzer** | The pipeline **MUST** fail if any finding is reported at **Error** or **Warning** severity for repository **`.ps1`** and **`.psm1`** files. |
| **Pester** | The pipeline **MUST** fail if any test fails (deterministic logic: provisioning CSV contract, IT department rule, identity derivation / nickname normalization, and other committed unit tests). |
| **Microsoft Graph** | Default CI **MUST NOT** invoke Microsoft Graph; absence of Graph calls in default workflows is a contractual control, not an optional optimization. |

### Vulnerability scanning (containers and dependencies)

| Artifact class | Break-the-build threshold |
|----------------|---------------------------|
| **Container images** (Dockerfile / OCI image produced by this repository) | If and when introduced: the pipeline **MUST** fail if static image scanning reports any **CRITICAL** or **HIGH** severity findings in OS packages **or** runtime dependencies included in the image. **MEDIUM** and below MAY be configured as advisory-only until a remediation SLA is defined by the organization. |
| **PowerShell modules (Microsoft.Graph et al.)** | Versions **MUST** be pinned per CONTEXT (`requirements.psd1` / module manifest); CI **MUST** install from that manifest only. Any pipeline step that detects unpinned or floating **latest** resolution for production apply paths **MUST** fail. Optional: fail on known-compromised module versions when an organizational feed or integrity catalog is available. |

**v1 repository reality:** CONTEXT describes **PowerShell** automation without mandating a project Dockerfile. Until a container build exists, container scanner stages are **not** required for merge; the **CRITICAL/HIGH** rule above applies **immediately** once a Dockerfile or image build is added.

### Container hardening (mandatory when a Dockerfile exists)

Any Dockerfile introduced for runners, tools, or apply sandboxes **MUST** satisfy all of the following:

1. **Non-root execution:** Create and use a dedicated unprivileged user (`USER` instruction); the default process **MUST NOT** run as `root` (UID 0).
2. **Minimal attack surface:** Base image **MUST** be minimal (`alpine`, `distroless`, or organization-approved slim variant); avoid full desktop or debug-oriented bases unless formally excepted.
3. **No elevated kernel privileges:** The image and `docker run` / Kubernetes pod spec **MUST NOT** use `--privileged`, `CAP_SYS_ADMIN`, or equivalent broad capability grants unless a written security exception exists with compensating controls.

---

## C. Secret & Configuration Management

| Variable Name | Classification | Storage Location | Injection Method |
|---------------|----------------|------------------|------------------|
| `AZURE_CLIENT_ID` (automation app) | NON-SECRET | GitHub Actions **Variables** (if OIDC to Azure/ARM), Terraform non-secret vars, or pipeline env | OIDC / Azure login action, `terraform` provider `client_id` |
| `AZURE_TENANT_ID` | NON-SECRET | Same as above | OIDC / Azure login action, `azuread` / `azurerm` tenant arguments |
| `AZURE_SUBSCRIPTION_ID` (ARM-only) | NON-SECRET | Same as above | Azure login / Terraform when subscription scope is required |
| Certificate **private key** for local Graph apply | SECRET | OS-protected store, **Azure Key Vault** secret, or HSM—**never** the repository | Script parameterization from secure path, Key Vault retrieval at runtime, or certificate store binding |
| Certificate **public** path / thumbprint (no key material) | NON-SECRET | Operator workstation config or parameter files **excluded** from git via `.gitignore` | Script `-CertificateThumbprint` / path arguments |
| `GITHUB_TOKEN` (default) | NON-SECRET (short-lived, scoped) | Provided by GitHub Actions runtime | Implicit `actions/checkout` and GitHub API steps |
| GitHub **encrypted secrets** for workflow-specific non-OIDC values (if any) | SECRET | GitHub **Secrets** on repository or **Environment** (`entra-apply`) | `secrets.*` in workflow YAML |
| Tenant **verified domain suffix** for UPN construction | NON-SECRET | Apply-time parameter or org config store (non-committed) | Script parameter / environment variable |
| **IT membership group** stable identifier (Object ID preferred) | NON-SECRET | Apply-time parameter or non-committed config | Script parameter |
| **Initial user passwords** (ephemeral apply output) | SECRET | **Not** stored in repo, CI logs, or artifacts; operator secure channel only | In-session console only; redacted default logging per CONTEXT |
| Terraform **backend** storage key (if key-based auth used) | SECRET | CI secret store or Key Vault—**prefer** OIDC + RBAC to blob so no account key is required | Pipeline auth to Azure Storage via workload identity; avoid shared keys |
| Microsoft Graph **access token** | SECRET (ephemeral) | Memory only | Microsoft.Graph module acquisition at runtime; never echo to logs |

**Repository rule:** No `.tfvars`, `.env`, or scripts committed with populated secrets, tenant-specific production identifiers used as authentication secrets, or private keys. Non-secret identifiers (`AZURE_TENANT_ID`, `AZURE_CLIENT_ID`) MAY appear in variables only when organizational policy allows; prefer **Environment**-scoped configuration for apply workflows.
