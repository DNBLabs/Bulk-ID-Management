<#
.SYNOPSIS
    Formats one row outcome for default console output with apply output hygiene.

.DESCRIPTION
    By default emits only line number and status. When ShowIdentifiers is set,
    includes UserPrincipalName and ObjectId when present. Never emits password material.

.PARAMETER RowOutcome
    Row outcome from New-ProvisioningRowOutcome.

.PARAMETER ShowIdentifiers
    When set, include UPN and object id in the formatted line for lab debugging.

.OUTPUTS
    System.String

.NOTES
    Private function; not exported. See CONTEXT.md apply output hygiene.
#>

function Format-ProvisioningRowOutcomeDisplayLine {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object] $RowOutcome,

        [Parameter()]
        [switch] $ShowIdentifiers
    )

    if ($null -eq $RowOutcome) {
        throw [System.ArgumentException]::new('Row outcome cannot be null.', 'RowOutcome')
    }

    $line = "Line $($RowOutcome.SourceLineNumber): $($RowOutcome.Status)"

    if ($RowOutcome.Status -eq $ProvisioningRowOutcomeStatusFailed -and
        -not [string]::IsNullOrWhiteSpace($RowOutcome.Reason)) {
        $sanitizedReason = Get-SanitizedProvisioningFailureReason -Message $RowOutcome.Reason
        $line = "$line ($sanitizedReason)"
    }

    if ($ShowIdentifiers) {
        $identifierParts = @()
        if (-not [string]::IsNullOrWhiteSpace($RowOutcome.UserPrincipalName)) {
            $identifierParts += "upn=$($RowOutcome.UserPrincipalName)"
        }
        if (-not [string]::IsNullOrWhiteSpace($RowOutcome.ObjectId)) {
            $identifierParts += "id=$($RowOutcome.ObjectId)"
        }
        if ($identifierParts.Count -gt 0) {
            $line = "$line [{0}]" -f ($identifierParts -join '; ')
        }
    }

    if ($line -match '(?i)password') {
        throw [System.InvalidOperationException]::new(
            'Formatted row outcome must not contain password material.')
    }

    return $line
}
