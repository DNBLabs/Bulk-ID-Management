<#
.SYNOPSIS
    Derives a UserPrincipalName for a provisioning row with bounded collision handling.

.DESCRIPTION
    Composes or parses UPN from mapped MailNickname and tenant domain suffix, or from
    optional CSV UserPrincipalName. Uses injectable UpnExists to select a free candidate.
    Does not call Get-MappedProvisioningIdentity or Microsoft Graph.

.PARAMETER ProvisioningRow
    Provisioning row from Import-ProvisioningCsv.

.PARAMETER MappedProvisioningIdentity
    Mapped identity from Get-MappedProvisioningIdentity.

.PARAMETER TenantDomainSuffix
    Verified domain (contoso.com or @contoso.com).

.PARAMETER UpnExists
    Script block receiving one canonical UPN string; returns true when taken.

.PARAMETER MaximumUpnCandidates
    Maximum exists-check probes per row (default 10, range 1-99).

.OUTPUTS
    PSCustomObject with UserPrincipalName, SourceLineNumber, and AttemptCount.

.NOTES
    Row failures throw InvalidOperationException with SourceLineNumber.
    UpnExists exceptions propagate unchanged.
#>
function Get-DerivedUserPrincipalName {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $ProvisioningRow,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $MappedProvisioningIdentity,

        [Parameter(Mandatory)]
        [string] $TenantDomainSuffix,

        [Parameter(Mandatory)]
        [scriptblock] $UpnExists,

        [Parameter()]
        [ValidateRange(1, 99)]
        [int] $MaximumUpnCandidates = $DefaultProvisioningMaximumUpnCandidates
    )

    if ($null -eq $DefaultProvisioningMaximumUpnCandidates) {
        throw [System.InvalidOperationException]::new(
            'Provisioning identity constants are not available in the current scope.'
        )
    }

    if ($null -eq $ProvisioningRow) {
        throw [System.ArgumentException]::new('Provisioning row cannot be null.')
    }

    if ($null -eq $MappedProvisioningIdentity) {
        throw [System.ArgumentException]::new('MappedProvisioningIdentity cannot be null.')
    }

    if ($null -eq $UpnExists) {
        throw [System.ArgumentException]::new('UpnExists script block cannot be null.')
    }

    if ($MaximumUpnCandidates -lt $MinProvisioningMaximumUpnCandidates -or
        $MaximumUpnCandidates -gt $MaxProvisioningMaximumUpnCandidates) {
        throw [System.ArgumentException]::new(
            "MaximumUpnCandidates must be between $MinProvisioningMaximumUpnCandidates and $MaxProvisioningMaximumUpnCandidates."
        )
    }

    Test-ProvisioningIdentityRowBoundary -ProvisioningRow $ProvisioningRow
    $sourceLineNumber = [int] $ProvisioningRow.SourceLineNumber

    $normalizedDomain = Get-NormalizedProvisioningTenantDomain -TenantDomainSuffix $TenantDomainSuffix
    $baseLocalPart = Get-ProvisioningUpnBaseLocalPart `
        -ProvisioningRow $ProvisioningRow `
        -MappedProvisioningIdentity $MappedProvisioningIdentity `
        -NormalizedDomain $normalizedDomain

    $attemptCount = 0
    for ($attemptIndex = 0; $attemptIndex -lt $MaximumUpnCandidates; $attemptIndex++) {
        $candidateUpn = Get-CanonicalProvisioningUpnCandidate `
            -BaseLocalPart $baseLocalPart `
            -NormalizedDomain $normalizedDomain `
            -AttemptIndex $attemptIndex

        $attemptCount++
        $isTaken = & $UpnExists $candidateUpn
        if (-not $isTaken) {
            return [PSCustomObject]@{
                UserPrincipalName = $candidateUpn
                SourceLineNumber  = $sourceLineNumber
                AttemptCount      = $attemptCount
            }
        }
    }

    throw [System.InvalidOperationException]::new(
        "No available UserPrincipalName found after $MaximumUpnCandidates attempts on physical line $sourceLineNumber."
    )
}
