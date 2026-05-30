<#
.SYNOPSIS
    Resolves GivenName, Surname, and DisplayName from a provisioning row.

.DESCRIPTION
    Applies CONTEXT.md Name mapping: defaults from FirstName and LastName, optional
    overrides from GivenName, Surname, and DisplayName row properties, diacritics
    preserved, trim and internal whitespace collapse on all outputs. DisplayName
    default uses FirstName and LastName (not mapped GivenName).

.PARAMETER ProvisioningRow
    Provisioning row object from Import-ProvisioningCsv.

.OUTPUTS
    Hashtable with keys GivenName, Surname, and DisplayName.

.NOTES
    Does not mutate the input row.
#>
function Get-ProvisioningNameMappingFromRow {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [object] $ProvisioningRow
    )

    $givenName = Format-ProvisioningIdentityNamePart -NamePart $ProvisioningRow.FirstName
    if ($ProvisioningRow.PSObject.Properties.Name -contains 'GivenName') {
        $givenName = Format-ProvisioningIdentityNamePart -NamePart $ProvisioningRow.GivenName
    }

    $surname = Format-ProvisioningIdentityNamePart -NamePart $ProvisioningRow.LastName
    if ($ProvisioningRow.PSObject.Properties.Name -contains 'Surname') {
        $surname = Format-ProvisioningIdentityNamePart -NamePart $ProvisioningRow.Surname
    }

    $displayFirstName = Format-ProvisioningIdentityNamePart -NamePart $ProvisioningRow.FirstName
    $displayLastName = Format-ProvisioningIdentityNamePart -NamePart $ProvisioningRow.LastName
    $displayName = "$displayFirstName $displayLastName".Trim()

    if ($ProvisioningRow.PSObject.Properties.Name -contains 'DisplayName') {
        $displayName = Format-ProvisioningIdentityNamePart -NamePart $ProvisioningRow.DisplayName
    }

    return @{
        GivenName   = $givenName
        Surname     = $surname
        DisplayName = $displayName
    }
}
