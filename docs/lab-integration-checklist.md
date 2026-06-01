# Lab integration checklist (non-CI)

Human verification in a **development tenant**. Default CI does **not** call Microsoft Graph; complete this checklist manually after code changes that affect apply, gateway retries, or reporting.

Normative contract: [CONTEXT.md](../CONTEXT.md). Operator steps: [runbook.md](runbook.md).

## Setup

- [ ] Automation principal has application permissions and admin consent per runbook.
- [ ] Certificate auth works (`Connect-ProvisioningGraph` succeeds).
- [ ] IT membership group Object ID is correct for `-ItMembershipGroupId`.
- [ ] Use [samples/provisioning-sample.csv](../samples/provisioning-sample.csv) or a copy with fictional data only.

## 1. Dry run then apply (happy path)

- [ ] **Dry run** with sample CSV: rows show planned **Created** / **MembershipEnsured** (or **Skipped** on re-run) without directory mutation.
- [ ] **Apply** without `-DryRun`: three sample users created (or **Skipped** if re-run).
- [ ] Script **ExitCode** is **0** when no row **Failed**.

## 2. IT membership ensure (idempotent re-run)

- [ ] First apply: row with Department **IT** (Grace Hopper) shows **MembershipEnsured** (or **Created** then membership).
- [ ] Second apply (no CSV changes): same row **Skipped** (existing UPN) and IT row still **MembershipEnsured** or membership no-op; user remains in IT group.
- [ ] Confirm in Entra portal: IT user is member of the IT group; no duplicate membership errors.

## 3. UpdateExisting limited fields

- [ ] Change **Department** (or name columns if using overrides) for an existing UPN in a test CSV.
- [ ] Run apply with **`-UpdateExisting`**: row outcome **Updated**; only `department`, `givenName`, `surname`, `displayName` change per CONTEXT (spot-check portal).
- [ ] Run apply **without** `-UpdateExisting` on same data: **Skipped**, no attribute drift.

## 4. Throttling and retries (spot-check)

- [ ] Optional: run a larger CSV or repeat rapid applies until Graph returns **429**.
- [ ] Observe bounded retries (backoff / **Retry-After** when present); row **Failed** only after policy cap, not infinite loop.
- [ ] Failed row cites throttling or timeout in reason; batch continues per **batch error policy**; **ExitCode** non-zero if any **Failed**.

## 5. Password and log hygiene

- [ ] New user apply: password **not** printed in default console output or saved transcript (unless you explicitly captured secure output).
- [ ] Default output does not include full UPN/object IDs unless **`-ShowIdentifiers`** was used.
- [ ] Review transcript file (if any): no password material, no committed secrets.

## 6. Batch error policy

- [ ] Introduce one bad row (invalid data or blocked UPN) in a small test CSV.
- [ ] Apply: other valid rows still process; failed row shows **Failed** with reason.
- [ ] **ExitCode** is **1**; fix data and re-run.

## Sign-off

| Date | Engineer | Tenant (alias) | Notes |
|------|----------|----------------|-------|
| | | | |
