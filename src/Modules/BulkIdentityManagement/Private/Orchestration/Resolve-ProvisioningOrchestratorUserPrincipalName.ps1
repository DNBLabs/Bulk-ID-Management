<#
.SYNOPSIS
    Resolves the canonical UPN and existing user Object ID for an orchestrator row.

.PARAMETER ProvisioningRow
    Materialized provisioning row.

.PARAMETER MappedProvisioningIdentity
    Output from Get-MappedProvisioningIdentity.

.PARAMETER TenantDomainSuffix
    Tenant domain suffix for UPN derivation.

.PARAMETER GraphGateway
    Task 7 gateway hashtable (uses TestUpnExists).

.OUTPUTS
    PSCustomObject with UserPrincipalName and ExistingUserId (nullable).
#>

function Resolve-ProvisioningOrchestratorUserPrincipalName {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $ProvisioningRow,

        [Parameter(Mandatory)]
        [object] $MappedProvisioningIdentity,

        [Parameter(Mandatory)]
        [string] $TenantDomainSuffix,

        [Parameter(Mandatory)]
        [hashtable] $GraphGateway
    )

    $normalizedDomain = Get-NormalizedProvisioningTenantDomain -TenantDomainSuffix $TenantDomainSuffix
    $baseLocalPart = Get-ProvisioningUpnBaseLocalPart `
        -ProvisioningRow $ProvisioningRow `
        -MappedProvisioningIdentity $MappedProvisioningIdentity `
        -NormalizedDomain $normalizedDomain
    $baseUpn = Get-CanonicalProvisioningUpnCandidate `
        -BaseLocalPart $baseLocalPart `
        -NormalizedDomain $normalizedDomain `
        -AttemptIndex 0

    $existingUserId = & $GraphGateway.TestUpnExists $baseUpn
    if ($existingUserId) {
        return [pscustomobject]@{
            UserPrincipalName = $baseUpn
            ExistingUserId    = $existingUserId
        }
    }

    $derived = Get-DerivedUserPrincipalName `
        -ProvisioningRow $ProvisioningRow `
        -MappedProvisioningIdentity $MappedProvisioningIdentity `
        -TenantDomainSuffix $TenantDomainSuffix `
        -UpnExists $GraphGateway.TestUpnExists

    return [pscustomobject]@{
        UserPrincipalName = $derived.UserPrincipalName
        ExistingUserId    = (& $GraphGateway.TestUpnExists $derived.UserPrincipalName)
    }
}
