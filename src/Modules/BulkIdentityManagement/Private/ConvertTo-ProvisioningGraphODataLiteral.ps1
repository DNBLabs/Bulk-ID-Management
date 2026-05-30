<#
.SYNOPSIS
    Escapes a string for use as an OData single-quoted literal in Graph filters.

.DESCRIPTION
    Doubles embedded apostrophes and rejects null or control characters in UPN literals.

.PARAMETER Value
    Raw string (typically a userPrincipalName).

.OUTPUTS
    System.String safe for insertion inside OData single quotes.
#>

function ConvertTo-ProvisioningGraphODataLiteral {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Value
    )

    if ($Value -match '[\x00-\x1F\x7F]') {
        throw [System.InvalidOperationException]::new(
            'Graph validation failed: UPN contains invalid control characters.')
    }

    return ($Value -replace "'", "''")
}
