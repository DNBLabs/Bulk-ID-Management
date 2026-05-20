<#
.SYNOPSIS
    Validates provisioning row inputs before identity mapping.

.DESCRIPTION
    Ensures required properties exist, SourceLineNumber is valid, string identity fields
    are within bounded lengths, and optional override cells respect the same bounds.

.PARAMETER ProvisioningRow
    Provisioning row from Import-ProvisioningCsv.

.NOTES
    Throws System.InvalidOperationException for contract violations on a row.
    Throws System.ArgumentException when the row object is null or missing required properties.
#>
function Test-ProvisioningIdentityRowBoundary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $ProvisioningRow
    )

    if ($null -eq $MaxProvisioningMailNicknameInputLength) {
        throw [System.InvalidOperationException]::new(
            'Provisioning identity constants are not available in the current scope.'
        )
    }

    if ($null -eq $ProvisioningRow) {
        throw [System.ArgumentException]::new('Provisioning row cannot be null.')
    }

    $requiredPropertyNames = @(
        'SourceLineNumber'
        'FirstName'
        'LastName'
        'Department'
    )

    foreach ($propertyName in $requiredPropertyNames) {
        if ($ProvisioningRow.PSObject.Properties.Name -notcontains $propertyName) {
            throw [System.ArgumentException]::new(
                "Provisioning row is missing required property '$propertyName'."
            )
        }
    }

    $lineNumber = [int] $ProvisioningRow.SourceLineNumber
    if ($lineNumber -lt 1) {
        throw [System.ArgumentException]::new(
            'Provisioning row SourceLineNumber must be a positive 1-based physical line number.'
        )
    }

    Test-ProvisioningIdentityStringFieldLength -FieldName 'FirstName' -Value $ProvisioningRow.FirstName -MaximumLength $MaxProvisioningIdentityGivenNameLength -SourceLineNumber $lineNumber
    Test-ProvisioningIdentityStringFieldLength -FieldName 'LastName' -Value $ProvisioningRow.LastName -MaximumLength $MaxProvisioningIdentitySurnameLength -SourceLineNumber $lineNumber
    Test-ProvisioningIdentityStringFieldLength -FieldName 'Department' -Value $ProvisioningRow.Department -MaximumLength $MaxProvisioningIdentityDisplayNameLength -SourceLineNumber $lineNumber

    foreach ($optionalName in @('GivenName', 'Surname', 'DisplayName', 'MailNickname', 'UserPrincipalName')) {
        if ($ProvisioningRow.PSObject.Properties.Name -contains $optionalName) {
            $maxLength = switch ($optionalName) {
                'GivenName' { $MaxProvisioningIdentityGivenNameLength }
                'Surname' { $MaxProvisioningIdentitySurnameLength }
                'DisplayName' { $MaxProvisioningIdentityDisplayNameLength }
                'MailNickname' { $MaxProvisioningMailNicknameInputLength }
                'UserPrincipalName' { $MaxProvisioningCsvUserPrincipalNameInputLength }
            }
            Test-ProvisioningIdentityStringFieldLength -FieldName $optionalName -Value $ProvisioningRow.$optionalName -MaximumLength $maxLength -SourceLineNumber $lineNumber
        }
    }
}

function Test-ProvisioningIdentityStringFieldLength {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $FieldName,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [object] $Value,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $MaximumLength,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $SourceLineNumber
    )

    if ($null -eq $Value) {
        throw [System.InvalidOperationException]::new(
            "Provisioning row field '$FieldName' cannot be null on physical line $SourceLineNumber."
        )
    }

    if ($Value -isnot [string]) {
        throw [System.InvalidOperationException]::new(
            "Provisioning row field '$FieldName' must be a string on physical line $SourceLineNumber."
        )
    }

    if ($Value.Length -gt $MaximumLength) {
        throw [System.InvalidOperationException]::new(
            "Provisioning row field '$FieldName' exceeds the maximum length of $MaximumLength characters on physical line $SourceLineNumber."
        )
    }
}

function Test-MappedProvisioningIdentityFieldLength {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $GivenName,

        [Parameter(Mandatory)]
        [string] $Surname,

        [Parameter(Mandatory)]
        [string] $DisplayName,

        [Parameter(Mandatory)]
        [string] $MailNickname,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $SourceLineNumber
    )

    if ($null -eq $MaxProvisioningMailNicknameLength) {
        throw [System.InvalidOperationException]::new(
            'Provisioning identity constants are not available in the current scope.'
        )
    }

    if ($GivenName.Length -gt $MaxProvisioningIdentityGivenNameLength) {
        throw [System.InvalidOperationException]::new(
            "Mapped GivenName exceeds the maximum length of $MaxProvisioningIdentityGivenNameLength characters on physical line $SourceLineNumber."
        )
    }

    if ($Surname.Length -gt $MaxProvisioningIdentitySurnameLength) {
        throw [System.InvalidOperationException]::new(
            "Mapped Surname exceeds the maximum length of $MaxProvisioningIdentitySurnameLength characters on physical line $SourceLineNumber."
        )
    }

    if ($DisplayName.Length -gt $MaxProvisioningIdentityDisplayNameLength) {
        throw [System.InvalidOperationException]::new(
            "Mapped DisplayName exceeds the maximum length of $MaxProvisioningIdentityDisplayNameLength characters on physical line $SourceLineNumber."
        )
    }

    if ($MailNickname.Length -gt $MaxProvisioningMailNicknameLength) {
        throw [System.InvalidOperationException]::new(
            "Mapped MailNickname exceeds the maximum length of $MaxProvisioningMailNicknameLength characters on physical line $SourceLineNumber."
        )
    }
}
