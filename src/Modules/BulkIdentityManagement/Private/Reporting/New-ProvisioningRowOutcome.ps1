<#
.SYNOPSIS
    Creates a structured provisioning row outcome for batch reporting.

.DESCRIPTION
    Returns a PSCustomObject with SourceLineNumber, Status, optional Reason,
    UserPrincipalName, and ObjectId. Status must be one of the CONTEXT row outcome
    labels defined in ProvisioningRowOutcome.Constants.ps1.

.PARAMETER SourceLineNumber
    Physical CSV line number for the provisioning row.

.PARAMETER Status
    Outcome label: Created, Skipped, Updated, MembershipEnsured, or Failed.

.PARAMETER Reason
    Human-readable failure reason when Status is Failed.

.PARAMETER UserPrincipalName
    Optional UPN for ShowIdentifiers display only; omitted from default output.

.PARAMETER ObjectId
    Optional directory object id for ShowIdentifiers display only.

.OUTPUTS
    System.Management.Automation.PSCustomObject

.NOTES
    Private function; not exported. See CONTEXT.md row outcome.
#>

function New-ProvisioningRowOutcome {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Constructs an in-memory outcome object; no external state change.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $SourceLineNumber,

        [Parameter(Mandatory)]
        [string] $Status,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Reason,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $UserPrincipalName,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $ObjectId
    )

    if ($null -eq $ValidProvisioningRowOutcomeStatuses) {
        throw [System.InvalidOperationException]::new(
            'Provisioning row outcome constants are not available in the current scope.')
    }

    if ($ValidProvisioningRowOutcomeStatuses -notcontains $Status) {
        throw [System.ArgumentException]::new(
            "Invalid row outcome status '$Status'.",
            'Status')
    }

    if ($Status -eq $ProvisioningRowOutcomeStatusFailed -and [string]::IsNullOrWhiteSpace($Reason)) {
        throw [System.ArgumentException]::new(
            'Failed row outcomes require a non-empty Reason.',
            'Reason')
    }

    return [pscustomobject]@{
        SourceLineNumber  = $SourceLineNumber
        Status            = $Status
        Reason            = $Reason
        UserPrincipalName = $UserPrincipalName
        ObjectId          = $ObjectId
    }
}
