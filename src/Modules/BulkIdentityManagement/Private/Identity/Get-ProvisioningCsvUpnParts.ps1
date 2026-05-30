<#
.SYNOPSIS
    Parses and validates a CSV UserPrincipalName for Identity derivation.

.DESCRIPTION
    Ensures exactly one @, non-empty local part and domain, and domain matches
    the normalized tenant suffix (case-insensitive).

.PARAMETER UserPrincipalName
    Trimmed CSV UserPrincipalName value.

.PARAMETER NormalizedDomain
    Normalized tenant domain suffix.

.PARAMETER SourceLineNumber
    Physical file line for error messages.

.OUTPUTS
    Hashtable with LocalPart and Domain keys.

.NOTES
    Throws System.InvalidOperationException when shape or domain is invalid.
#>
function Get-ProvisioningCsvUpnParts {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns',
        '',
        Justification = 'Cmdlet returns one UPN parts hashtable (local part and domain) per call.')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string] $UserPrincipalName,

        [Parameter(Mandatory)]
        [string] $NormalizedDomain,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $SourceLineNumber
    )

    if ($null -eq $MaxProvisioningCsvUserPrincipalNameInputLength) {
        throw [System.InvalidOperationException]::new(
            'Provisioning identity constants are not available in the current scope.'
        )
    }

    if ($UserPrincipalName.Length -gt $MaxProvisioningCsvUserPrincipalNameInputLength) {
        throw [System.InvalidOperationException]::new(
            "UserPrincipalName exceeds the maximum length of $MaxProvisioningCsvUserPrincipalNameInputLength characters on physical line $SourceLineNumber."
        )
    }

    $atPositions = @()
    for ($index = 0; $index -lt $UserPrincipalName.Length; $index++) {
        if ($UserPrincipalName[$index] -eq '@') {
            $atPositions += $index
        }
    }

    if ($atPositions.Count -ne 1) {
        throw [System.InvalidOperationException]::new(
            "UserPrincipalName must contain exactly one '@' on physical line $SourceLineNumber."
        )
    }

    $atIndex = $atPositions[0]
    $localPart = $UserPrincipalName.Substring(0, $atIndex).Trim()
    $domainPart = $UserPrincipalName.Substring($atIndex + 1).Trim()

    if ([string]::IsNullOrWhiteSpace($localPart) -or [string]::IsNullOrWhiteSpace($domainPart)) {
        throw [System.InvalidOperationException]::new(
            "UserPrincipalName must have non-empty local part and domain on physical line $SourceLineNumber."
        )
    }

    if (-not $domainPart.Equals($NormalizedDomain, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw [System.InvalidOperationException]::new(
            "UserPrincipalName domain does not match tenant domain suffix on physical line $SourceLineNumber."
        )
    }

    return @{
        LocalPart = $localPart
        Domain    = $NormalizedDomain
    }
}
