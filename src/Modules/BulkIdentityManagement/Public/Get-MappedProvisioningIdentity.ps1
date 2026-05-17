<#
.SYNOPSIS
    Maps a provisioning row to Entra-ready identity fields and a normalized MailNickname.

.DESCRIPTION
    Applies Name mapping and MailNickname normalization per CONTEXT.md. Returns a new
    mapped provisioning identity object without mutating the input row. UserPrincipalName
    is not set here (Task 5 Identity derivation).

.PARAMETER ProvisioningRow
    Provisioning row object from Import-ProvisioningCsv.

.OUTPUTS
    PSCustomObject with SourceLineNumber, GivenName, Surname, DisplayName, and MailNickname.

.NOTES
    Throws System.InvalidOperationException when MailNickname normalization fails.
    Throws ArgumentException when required row properties are missing.
#>
function Get-MappedProvisioningIdentity {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $ProvisioningRow
    )

    if ($null -eq $ProvisioningRow) {
        throw [System.ArgumentException]::new('Provisioning row cannot be null.')
    }

    Test-ProvisioningIdentityRowBoundary -ProvisioningRow $ProvisioningRow
    $sourceLineNumber = [int] $ProvisioningRow.SourceLineNumber

    $nameMapping = Get-ProvisioningNameMappingFromRow -ProvisioningRow $ProvisioningRow

    if ($ProvisioningRow.PSObject.Properties.Name -contains 'MailNickname') {
        $mailNickname = Get-NormalizedProvisioningMailNickname `
            -NicknameInput $ProvisioningRow.MailNickname `
            -SourceLineNumber $sourceLineNumber
    }
    else {
        $nicknameBase = "$($nameMapping.GivenName).$($nameMapping.Surname)"
        $mailNickname = Get-NormalizedProvisioningMailNickname `
            -NicknameInput $nicknameBase `
            -SourceLineNumber $sourceLineNumber
    }

    Test-MappedProvisioningIdentityFieldLengths `
        -GivenName $nameMapping.GivenName `
        -Surname $nameMapping.Surname `
        -DisplayName $nameMapping.DisplayName `
        -MailNickname $mailNickname `
        -SourceLineNumber $sourceLineNumber

    return [PSCustomObject]@{
        SourceLineNumber = $sourceLineNumber
        GivenName          = $nameMapping.GivenName
        Surname            = $nameMapping.Surname
        DisplayName        = $nameMapping.DisplayName
        MailNickname       = $mailNickname
    }
}
