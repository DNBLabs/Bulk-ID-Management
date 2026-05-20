<#
.SYNOPSIS
    Pester tests for Task 5 UPN collision suffix via Get-DerivedUserPrincipalName.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop

    function script:New-TestProvisioningRow {
        param([Parameter(Mandatory)][hashtable] $Properties)
        if (-not $Properties.ContainsKey('SourceLineNumber')) { $Properties['SourceLineNumber'] = 2 }
        if (-not $Properties.ContainsKey('Department')) { $Properties['Department'] = 'Engineering' }
        return [PSCustomObject] $Properties
    }

    function script:New-TestMappedIdentity {
        param([string] $MailNickname, [int] $SourceLineNumber = 2)
        return [PSCustomObject]@{
            SourceLineNumber = $SourceLineNumber
            GivenName          = 'Jane'
            Surname            = 'Doe'
            DisplayName        = 'Jane Doe'
            MailNickname       = $MailNickname
        }
    }
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 5 - collision suffix via Get-DerivedUserPrincipalName' {

    It 'appends suffix 2 when base UPN is taken' {
        $row = New-TestProvisioningRow -Properties @{ FirstName = 'Jane'; LastName = 'Doe' }
        $mapped = New-TestMappedIdentity -MailNickname 'jane.doe'
        $taken = @{ 'jane.doe@contoso.com' = $true }

        $derived = Get-DerivedUserPrincipalName `
            -ProvisioningRow $row `
            -MappedProvisioningIdentity $mapped `
            -TenantDomainSuffix 'contoso.com' `
            -UpnExists {
                param($UserPrincipalName)
                $taken.ContainsKey($UserPrincipalName)
            }

        $derived.UserPrincipalName | Should -Be 'jane.doe2@contoso.com'
        $derived.AttemptCount | Should -Be 2
    }

    It 'appends suffix 3 when base and suffix 2 are taken' {
        $row = New-TestProvisioningRow -Properties @{ FirstName = 'Jane'; LastName = 'Doe' }
        $mapped = New-TestMappedIdentity -MailNickname 'jane.doe'
        $taken = @{
            'jane.doe@contoso.com'  = $true
            'jane.doe2@contoso.com' = $true
        }

        $derived = Get-DerivedUserPrincipalName `
            -ProvisioningRow $row `
            -MappedProvisioningIdentity $mapped `
            -TenantDomainSuffix 'contoso.com' `
            -UpnExists {
                param($UserPrincipalName)
                $taken.ContainsKey($UserPrincipalName)
            }

        $derived.UserPrincipalName | Should -Be 'jane.doe3@contoso.com'
        $derived.AttemptCount | Should -Be 3
    }

    It 'appends suffix 2 when base local part already ends with a digit' {
        $row = New-TestProvisioningRow -Properties @{ FirstName = 'Ada'; LastName = 'Two' }
        $mapped = New-TestMappedIdentity -MailNickname 'ada2'
        $taken = @{ 'ada2@contoso.com' = $true }

        $derived = Get-DerivedUserPrincipalName `
            -ProvisioningRow $row `
            -MappedProvisioningIdentity $mapped `
            -TenantDomainSuffix 'contoso.com' `
            -UpnExists {
                param($UserPrincipalName)
                $taken.ContainsKey($UserPrincipalName)
            }

        $derived.UserPrincipalName | Should -Be 'ada22@contoso.com'
        $derived.AttemptCount | Should -Be 2
    }
}
