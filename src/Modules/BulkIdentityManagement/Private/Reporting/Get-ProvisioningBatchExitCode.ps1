<#
.SYNOPSIS
    Computes process exit code from provisioning row outcomes.

.DESCRIPTION
    Returns 0 when no row failed; 1 when any row has Failed status per CONTEXT
    batch error policy.

.PARAMETER RowOutcomes
    Array of row outcome objects from the orchestrator.

.OUTPUTS
    System.Int32

.NOTES
    Private function; not exported.
#>

function Get-ProvisioningBatchExitCode {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $RowOutcomes
    )

    if ($null -eq $ProvisioningRowOutcomeStatusFailed) {
        throw [System.InvalidOperationException]::new(
            'Provisioning row outcome constants are not available in the current scope.')
    }

    foreach ($outcome in $RowOutcomes) {
        if ($null -ne $outcome -and $outcome.Status -eq $ProvisioningRowOutcomeStatusFailed) {
            return 1
        }
    }

    return 0
}
