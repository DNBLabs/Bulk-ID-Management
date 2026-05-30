<#
.SYNOPSIS
    Canonical row outcome status labels for provisioning batch reporting.

.DESCRIPTION
    Defines the allowed Status values for New-ProvisioningRowOutcome per CONTEXT.md
    row outcome vocabulary. Consumed by reporting helpers and the apply orchestrator.
#>

$script:ProvisioningRowOutcomeStatusCreated = 'Created'
$script:ProvisioningRowOutcomeStatusSkipped = 'Skipped'
$script:ProvisioningRowOutcomeStatusUpdated = 'Updated'
$script:ProvisioningRowOutcomeStatusMembershipEnsured = 'MembershipEnsured'
$script:ProvisioningRowOutcomeStatusFailed = 'Failed'

$script:ValidProvisioningRowOutcomeStatuses = @(
    $script:ProvisioningRowOutcomeStatusCreated
    $script:ProvisioningRowOutcomeStatusSkipped
    $script:ProvisioningRowOutcomeStatusUpdated
    $script:ProvisioningRowOutcomeStatusMembershipEnsured
    $script:ProvisioningRowOutcomeStatusFailed
)
