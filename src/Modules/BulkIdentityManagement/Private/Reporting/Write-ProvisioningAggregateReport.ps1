<#
.SYNOPSIS
    Writes per-row and aggregate provisioning outcome lines to an output writer.

.DESCRIPTION
    Formats each row outcome with apply output hygiene defaults and writes a summary
    count line. Does not write password material.

.PARAMETER RowOutcomes
    Row outcomes collected during batch processing.

.PARAMETER ShowIdentifiers
    Passed through to Format-ProvisioningRowOutcomeDisplayLine.

.PARAMETER OutputWriter
    Script block invoked with one formatted string per line. Defaults to Write-Output.

.NOTES
    Private function; not exported.
#>

function Write-ProvisioningAggregateReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $RowOutcomes,

        [Parameter()]
        [switch] $ShowIdentifiers,

        [Parameter()]
        [scriptblock] $OutputWriter = { param([string] $Line) Write-Output $Line }
    )

    if ($null -eq $ValidProvisioningRowOutcomeStatuses) {
        throw [System.InvalidOperationException]::new(
            'Provisioning row outcome constants are not available in the current scope.')
    }

    $counts = @{}
    foreach ($status in $ValidProvisioningRowOutcomeStatuses) {
        $counts[$status] = 0
    }

    foreach ($outcome in $RowOutcomes) {
        if ($null -eq $outcome) {
            continue
        }

        $line = Format-ProvisioningRowOutcomeDisplayLine -RowOutcome $outcome -ShowIdentifiers:$ShowIdentifiers
        & $OutputWriter $line

        if ($counts.ContainsKey($outcome.Status)) {
            $counts[$outcome.Status]++
        }
    }

    $summaryParts = foreach ($status in $ValidProvisioningRowOutcomeStatuses) {
        if ($counts[$status] -gt 0) {
            "{0}={1}" -f $status, $counts[$status]
        }
    }

    $summaryLine = 'Summary: ' + ($summaryParts -join ', ')
    if ($summaryLine -match '(?i)password') {
        throw [System.InvalidOperationException]::new(
            'Aggregate summary must not contain password material.')
    }

    & $OutputWriter $summaryLine
}
