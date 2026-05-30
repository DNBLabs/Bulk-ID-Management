<#
.SYNOPSIS
    Validates mapped provisioning identity input for Identity derivation.

.DESCRIPTION
    Ensures required properties exist and MailNickname is non-empty before UPN composition.

.PARAMETER MappedProvisioningIdentity
    Mapped identity from Get-MappedProvisioningIdentity.

.PARAMETER SourceLineNumber
    Physical line number from the provisioning row.

.NOTES
    Throws ArgumentException for malformed objects; InvalidOperationException for empty MailNickname.
#>
function Test-MappedProvisioningIdentityBoundary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $MappedProvisioningIdentity,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $SourceLineNumber
    )

    if ($null -eq $MappedProvisioningIdentity) {
        throw [System.ArgumentException]::new('MappedProvisioningIdentity cannot be null.')
    }

    $requiredPropertyNames = @(
        'SourceLineNumber'
        'MailNickname'
    )

    foreach ($propertyName in $requiredPropertyNames) {
        if ($MappedProvisioningIdentity.PSObject.Properties.Name -notcontains $propertyName) {
            throw [System.ArgumentException]::new(
                "Mapped provisioning identity is missing required property '$propertyName'."
            )
        }
    }

    $mailNickname = [string] $MappedProvisioningIdentity.MailNickname
    if ([string]::IsNullOrWhiteSpace($mailNickname)) {
        throw [System.InvalidOperationException]::new(
            "Mapped MailNickname cannot be empty on physical line $SourceLineNumber."
        )
    }
}
