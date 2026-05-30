<#
.SYNOPSIS
    Normalizes the tenant domain suffix for UPN composition.

.DESCRIPTION
    Trims input, strips a leading @, and validates non-empty bounded length.
    Used by Identity derivation (Task 5).

.PARAMETER TenantDomainSuffix
    Verified domain suffix (e.g. contoso.com or @contoso.com).

.OUTPUTS
    System.String domain without leading @.

.NOTES
    Throws System.ArgumentException when suffix is empty or exceeds max length.
#>
function Get-NormalizedProvisioningTenantDomain {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $TenantDomainSuffix
    )

    if ($null -eq $MaxProvisioningTenantDomainSuffixLength) {
        throw [System.InvalidOperationException]::new(
            'Provisioning identity constants are not available in the current scope.'
        )
    }

    $trimmed = $TenantDomainSuffix.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        throw [System.ArgumentException]::new('TenantDomainSuffix cannot be empty or whitespace.')
    }

    if ($trimmed.StartsWith('@', [System.StringComparison]::Ordinal)) {
        $trimmed = $trimmed.Substring(1).Trim()
    }

    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        throw [System.ArgumentException]::new('TenantDomainSuffix cannot be empty or whitespace.')
    }

    if ($trimmed.Length -gt $MaxProvisioningTenantDomainSuffixLength) {
        throw [System.ArgumentException]::new(
            "TenantDomainSuffix exceeds the maximum length of $MaxProvisioningTenantDomainSuffixLength characters."
        )
    }

    return $trimmed
}
