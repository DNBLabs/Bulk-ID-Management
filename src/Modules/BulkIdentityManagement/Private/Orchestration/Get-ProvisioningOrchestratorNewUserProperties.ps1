<#
.SYNOPSIS
    Builds the NewUser property hashtable for the Graph gateway from a mapped row.

.PARAMETER Row
    Provisioning row.

.PARAMETER Mapped
    Mapped provisioning identity.

.PARAMETER UserPrincipalName
    Canonical UPN for the new user.

.PARAMETER UsageLocation
    Optional ISO usage location applied on create.

.OUTPUTS
    Hashtable of user properties (no password).
#>

function Get-ProvisioningOrchestratorNewUserProperties {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '',
        Justification = 'Properties reflects a property bag returned for Graph NewUser.')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [object] $Row,

        [Parameter(Mandatory)]
        [object] $Mapped,

        [Parameter(Mandatory)]
        [string] $UserPrincipalName,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $UsageLocation
    )

    $properties = @{
        userPrincipalName = $UserPrincipalName
        mailNickname      = $Mapped.MailNickname
        givenName         = $Mapped.GivenName
        surname           = $Mapped.Surname
        displayName       = $Mapped.DisplayName
        department        = $Row.Department.Trim()
        accountEnabled    = $true
    }

    if (-not [string]::IsNullOrWhiteSpace($UsageLocation)) {
        $properties['usageLocation'] = $UsageLocation.Trim()
    }

    return $properties
}
