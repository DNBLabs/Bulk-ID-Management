<#
.SYNOPSIS
    Ensures IT group membership for a resolved user via the Graph gateway.

.PARAMETER UserId
    Directory user Object ID, or null during dry-run create paths.

.PARAMETER UserPrincipalName
    Canonical UPN for error messages.

.PARAMETER GraphGateway
    Task 7 gateway hashtable.

.PARAMETER ItMembershipGroupId
    IT membership group Object ID.

.PARAMETER DryRun
    When true, performs read-only membership checks only.

.PARAMETER PrimaryStatus
    Row status before membership ensure (controls MembershipEnsured outcome).

.OUTPUTS
    Optional status string when membership ensure changes the row outcome label.
#>

function Invoke-ProvisioningOrchestratorItMembership {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [string] $UserId,

        [Parameter(Mandatory)]
        [string] $UserPrincipalName,

        [Parameter(Mandatory)]
        [hashtable] $GraphGateway,

        [Parameter(Mandatory)]
        [string] $ItMembershipGroupId,

        [Parameter(Mandatory)]
        [bool] $DryRun,

        [Parameter(Mandatory)]
        [string] $PrimaryStatus
    )

    if ([string]::IsNullOrWhiteSpace($UserId)) {
        if ($DryRun) {
            return $null
        }

        throw [System.InvalidOperationException]::new(
            "Cannot ensure IT membership for UPN '$UserPrincipalName' without a resolved user Object ID.")
    }

    [void] (& $GraphGateway.GetGroupById $ItMembershipGroupId)

    $isMember = & $GraphGateway.TestGroupMembership $UserId $ItMembershipGroupId
    if ($isMember) {
        return $null
    }

    if ($DryRun) {
        if ($PrimaryStatus -eq $ProvisioningRowOutcomeStatusSkipped) {
            return $ProvisioningRowOutcomeStatusMembershipEnsured
        }

        return $null
    }

    & $GraphGateway.AddGroupMember $UserId $ItMembershipGroupId

    if ($PrimaryStatus -eq $ProvisioningRowOutcomeStatusSkipped) {
        return $ProvisioningRowOutcomeStatusMembershipEnsured
    }

    return $null
}
