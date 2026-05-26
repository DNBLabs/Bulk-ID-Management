<#
.SYNOPSIS
    Tests whether a Department value matches a configurable target for IT membership qualification.

.DESCRIPTION
    Trims both Department and Target, then performs a case-insensitive equality check.
    Returns $true when they match, $false otherwise. Null, empty, or whitespace-only
    Department returns $false without throwing. Consumed by the orchestrator to decide
    IT membership group eligibility per CONTEXT IT department rule.

.PARAMETER Department
    The Department value from a provisioning row. Caller passes $row.Department.

.PARAMETER Target
    The department name to match against. Default 'IT'. Trimmed before comparison.

.OUTPUTS
    System.Boolean

.NOTES
    Private function; not exported. See CONTEXT.md IT department rule.
#>

function Test-ProvisioningDepartmentMatch {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Department,

        [Parameter()]
        [string] $Target = 'IT'
    )

    if ([string]::IsNullOrWhiteSpace($Department)) {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($Target)) {
        return $false
    }

    return $Department.Trim().Equals($Target.Trim(), [System.StringComparison]::OrdinalIgnoreCase)
}
