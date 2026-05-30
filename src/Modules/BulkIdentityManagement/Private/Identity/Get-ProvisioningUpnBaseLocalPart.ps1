<#
.SYNOPSIS
    Resolves the base UPN local part for Identity derivation.

.DESCRIPTION
    Uses CSV UserPrincipalName local part when present on the row; otherwise MailNickname
    from mapped provisioning identity verbatim.

.PARAMETER ProvisioningRow
    Provisioning row from Import-ProvisioningCsv.

.PARAMETER MappedProvisioningIdentity
    Mapped identity from Get-MappedProvisioningIdentity.

.PARAMETER NormalizedDomain
    Normalized tenant domain suffix.

.OUTPUTS
    System.String base local part (not yet suffixed for collision).

.NOTES
    Throws when CSV UPN is invalid or MailNickname is required but empty.
#>
function Get-ProvisioningUpnBaseLocalPart {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object] $ProvisioningRow,

        [Parameter(Mandatory)]
        [object] $MappedProvisioningIdentity,

        [Parameter(Mandatory)]
        [string] $NormalizedDomain
    )

    $sourceLineNumber = [int] $ProvisioningRow.SourceLineNumber

    if ($ProvisioningRow.PSObject.Properties.Name -contains 'UserPrincipalName') {
        $csvUpn = [string] $ProvisioningRow.UserPrincipalName
        $parts = Get-ProvisioningCsvUpnParts `
            -UserPrincipalName $csvUpn.Trim() `
            -NormalizedDomain $NormalizedDomain `
            -SourceLineNumber $sourceLineNumber

        return [string] $parts.LocalPart
    }

    Test-MappedProvisioningIdentityBoundary `
        -MappedProvisioningIdentity $MappedProvisioningIdentity `
        -SourceLineNumber $sourceLineNumber

    return [string] $MappedProvisioningIdentity.MailNickname
}
