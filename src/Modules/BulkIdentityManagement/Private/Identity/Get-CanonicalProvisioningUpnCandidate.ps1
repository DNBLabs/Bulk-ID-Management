<#
.SYNOPSIS
    Builds a canonical lowercase UserPrincipalName candidate for one collision attempt.

.DESCRIPTION
    Composes localPart@domain. When AttemptIndex is 0, uses base local part only.
    When AttemptIndex is 1 or greater, appends digits (2, 3, ...) to the end of the base local part.

.PARAMETER BaseLocalPart
    Base UPN local part before collision suffix.

.PARAMETER NormalizedDomain
    Tenant domain without leading @.

.PARAMETER AttemptIndex
    Zero-based attempt index (0 = base, 1 = suffix 2, 2 = suffix 3, ...).

.OUTPUTS
    System.String canonical lowercase UPN.

.NOTES
    Throws System.InvalidOperationException when composed UPN exceeds max length.
#>
function Get-CanonicalProvisioningUpnCandidate {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $BaseLocalPart,

        [Parameter(Mandatory)]
        [string] $NormalizedDomain,

        [Parameter(Mandatory)]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $AttemptIndex
    )

    if ($null -eq $MaxProvisioningUserPrincipalNameLength) {
        throw [System.InvalidOperationException]::new(
            'Provisioning identity constants are not available in the current scope.'
        )
    }

    $localPart = $BaseLocalPart
    if ($AttemptIndex -gt 0) {
        $suffixDigits = [string]($AttemptIndex + 1)
        $localPart = "$BaseLocalPart$suffixDigits"
    }

    $candidate = "$localPart@$NormalizedDomain".ToLowerInvariant()

    if ($candidate.Length -gt $MaxProvisioningUserPrincipalNameLength) {
        throw [System.InvalidOperationException]::new(
            "Composed UserPrincipalName exceeds the maximum length of $MaxProvisioningUserPrincipalNameLength characters."
        )
    }

    return $candidate
}
