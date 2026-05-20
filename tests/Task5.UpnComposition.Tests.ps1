<#
.SYNOPSIS
    Pester tests for Task 5 UPN composition via Get-DerivedUserPrincipalName.

.DESCRIPTION
    Asserts nickname-built UserPrincipalName and tenant domain suffix behavior.
    Imports the root script module only (no manifest Graph dependency).
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'

    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop

    function script:New-TestProvisioningRow {
        param([Parameter(Mandatory)][hashtable] $Properties)

        if (-not $Properties.ContainsKey('SourceLineNumber')) {
            $Properties['SourceLineNumber'] = 2
        }

        if (-not $Properties.ContainsKey('Department')) {
            $Properties['Department'] = 'Engineering'
        }

        return [PSCustomObject] $Properties
    }

    function script:New-TestMappedIdentity {
        param(
            [string] $MailNickname = 'ada.lovelace',
            [int] $SourceLineNumber = 2
        )

        return [PSCustomObject]@{
            SourceLineNumber = $SourceLineNumber
            GivenName          = 'Ada'
            Surname            = 'Lovelace'
            DisplayName        = 'Ada Lovelace'
            MailNickname       = $MailNickname
        }
    }
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 5 - nickname-built UPN via Get-DerivedUserPrincipalName' {

    It 'returns canonical lowercase UPN from MailNickname and contoso.com when UpnExists is false' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName = 'Ada'
            LastName  = 'Lovelace'
        }
        $mapped = New-TestMappedIdentity -MailNickname 'ada.lovelace' -SourceLineNumber 2

        $derived = Get-DerivedUserPrincipalName `
            -ProvisioningRow $row `
            -MappedProvisioningIdentity $mapped `
            -TenantDomainSuffix 'contoso.com' `
            -UpnExists { $false }

        $derived.UserPrincipalName | Should -Be 'ada.lovelace@contoso.com'
        $derived.SourceLineNumber | Should -Be 2
        $derived.AttemptCount | Should -Be 1
    }

    It 'normalizes @contoso.com tenant suffix the same as contoso.com' {
        $row = New-TestProvisioningRow -Properties @{ FirstName = 'Ada'; LastName = 'Lovelace' }
        $mapped = New-TestMappedIdentity -MailNickname 'ada.lovelace'

        $derived = Get-DerivedUserPrincipalName `
            -ProvisioningRow $row `
            -MappedProvisioningIdentity $mapped `
            -TenantDomainSuffix '@contoso.com' `
            -UpnExists { $false }

        $derived.UserPrincipalName | Should -Be 'ada.lovelace@contoso.com'
    }
}
