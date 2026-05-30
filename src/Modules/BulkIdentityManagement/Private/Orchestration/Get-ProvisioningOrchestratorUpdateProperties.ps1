<#
.SYNOPSIS
    Builds the UpdateUser patch hashtable for the Graph gateway from a mapped row.

.PARAMETER Row
    Provisioning row.

.PARAMETER Mapped
    Mapped provisioning identity.

.OUTPUTS
    Hashtable with department, givenName, surname, displayName.
#>

function Get-ProvisioningOrchestratorUpdateProperties {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '',
        Justification = 'Properties reflects a property bag returned for Graph UpdateUser.')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [object] $Row,

        [Parameter(Mandatory)]
        [object] $Mapped
    )

    return @{
        department  = $Row.Department.Trim()
        givenName   = $Mapped.GivenName
        surname     = $Mapped.Surname
        displayName = $Mapped.DisplayName
    }
}
