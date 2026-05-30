<#
.SYNOPSIS
    Runs dry-run or apply provisioning for CSV rows against a Graph gateway contract.

.DESCRIPTION
    For each provisioning row: maps identity, derives UPN, resolves user and IT membership
    through the supplied gateway ScriptBlocks. Dry run performs read-only gateway calls only.
    Apply creates, skips, or updates users per CONTEXT re-run behavior and ensures IT group
    membership for qualifying rows. Row failures are collected; batch continues.

.PARAMETER ProvisioningRows
    Materialized rows from Import-ProvisioningCsv.

.PARAMETER GraphGateway
    Hashtable with six gateway ScriptBlocks per Task 7 contract.

.PARAMETER TenantDomainSuffix
    Tenant domain suffix for UPN derivation.

.PARAMETER ItMembershipGroupId
    Object ID of the pre-created IT membership group.

.PARAMETER DryRun
    When set, performs no mutating gateway operations.

.PARAMETER UpdateExisting
    When set, patches limited attributes for existing users.

.PARAMETER ItDepartmentTarget
    Department value that qualifies for IT membership ensure.

.PARAMETER UsageLocation
    Optional usage location applied on user create only.

.PARAMETER ShowIdentifiers
    Passed through to aggregate reporting (consumed by a future entry script).

.OUTPUTS
    PSCustomObject with RowOutcomes, ExitCode, and DryRun flag.

.NOTES
    Private function; not exported until Task 13 entry wiring.
#>

function Invoke-ProvisioningOrchestrator {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'DryRun switch prevents mutations; apply mutations are explicit gateway calls.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $ProvisioningRows,

        [Parameter(Mandatory)]
        [hashtable] $GraphGateway,

        [Parameter(Mandatory)]
        [string] $TenantDomainSuffix,

        [Parameter(Mandatory)]
        [string] $ItMembershipGroupId,

        [Parameter()]
        [switch] $DryRun,

        [Parameter()]
        [switch] $UpdateExisting,

        [Parameter()]
        [string] $ItDepartmentTarget = 'IT',

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $UsageLocation,

        [Parameter()]
        [switch] $ShowIdentifiers
    )

    Test-ProvisioningGraphGatewayContract -GraphGateway $GraphGateway

    $parsedGroupId = [guid]::Empty
    if (-not [guid]::TryParse($ItMembershipGroupId, [ref]$parsedGroupId)) {
        throw [System.ArgumentException]::new(
            'IT membership group id must be a valid GUID.',
            'ItMembershipGroupId')
    }

    $outcomes = [System.Collections.Generic.List[object]]::new()

    foreach ($row in $ProvisioningRows) {
        $lineNumber = [int] $row.SourceLineNumber
        try {
            $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row
            $resolvedUpn = Resolve-ProvisioningOrchestratorUserPrincipalName `
                -ProvisioningRow $row `
                -MappedProvisioningIdentity $mapped `
                -TenantDomainSuffix $TenantDomainSuffix `
                -GraphGateway $GraphGateway
            $upn = $resolvedUpn.UserPrincipalName
            $existingUserId = $resolvedUpn.ExistingUserId
            $qualifiesForItMembership = Test-ProvisioningDepartmentMatch `
                -Department $row.Department `
                -Target $ItDepartmentTarget

            $outcome = Invoke-ProvisioningOrchestratorRow `
                -Row $row `
                -Mapped $mapped `
                -UserPrincipalName $upn `
                -ExistingUserId $existingUserId `
                -QualifiesForItMembership $qualifiesForItMembership `
                -GraphGateway $GraphGateway `
                -ItMembershipGroupId $ItMembershipGroupId `
                -DryRun:$DryRun `
                -UpdateExisting:$UpdateExisting `
                -UsageLocation $UsageLocation

            $outcomes.Add($outcome)
        }
        catch {
            $reason = $_.Exception.Message
            if ($_.Exception.InnerException) {
                $reason = $_.Exception.InnerException.Message
            }

            $safeReason = Get-SanitizedProvisioningFailureReason -Message $reason

            $outcomes.Add((New-ProvisioningRowOutcome `
                -SourceLineNumber $lineNumber `
                -Status $ProvisioningRowOutcomeStatusFailed `
                -Reason $safeReason))
        }
    }

    $outcomeArray = @($outcomes.ToArray())
    return [pscustomobject]@{
        RowOutcomes     = $outcomeArray
        ExitCode        = (Get-ProvisioningBatchExitCode -RowOutcomes $outcomeArray)
        DryRun          = [bool] $DryRun
        ShowIdentifiers = [bool] $ShowIdentifiers
    }
}
