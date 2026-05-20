<#
.SYNOPSIS
    Pester tests for Task 5 CSV UserPrincipalName override via Get-DerivedUserPrincipalName.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop

    function script:New-TestMappedIdentity {
        return [PSCustomObject]@{
            SourceLineNumber = 5
            GivenName          = 'Ignored'
            Surname            = 'Nick'
            DisplayName        = 'Ignored Nick'
            MailNickname       = 'should.not.use'
        }
    }
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 5 - CSV UserPrincipalName override' {

    It 'uses CSV UPN local part and applies collision suffix when base is taken' {
        $row = [PSCustomObject]@{
            SourceLineNumber  = 5
            FirstName         = 'Custom'
            LastName          = 'Alias'
            Department        = 'IT'
            UserPrincipalName = 'Custom.Alias@contoso.com'
        }
        $mapped = New-TestMappedIdentity
        $taken = @{ 'custom.alias@contoso.com' = $true }
        $probes = [System.Collections.Generic.List[string]]::new()

        $derived = Get-DerivedUserPrincipalName `
            -ProvisioningRow $row `
            -MappedProvisioningIdentity $mapped `
            -TenantDomainSuffix 'contoso.com' `
            -UpnExists {
                param($UserPrincipalName)
                $probes.Add($UserPrincipalName) | Out-Null
                $taken.ContainsKey($UserPrincipalName)
            }

        $derived.UserPrincipalName | Should -Be 'custom.alias2@contoso.com'
        $probes[0] | Should -Be 'custom.alias@contoso.com'
        $probes.Count | Should -Be 2
    }

    It 'fails when CSV UPN domain does not match tenant suffix' {
        $row = [PSCustomObject]@{
            SourceLineNumber  = 7
            FirstName         = 'Ada'
            LastName          = 'Lovelace'
            Department        = 'Engineering'
            UserPrincipalName = 'ada@fabrikam.com'
        }
        $mapped = New-TestMappedIdentity

        { Get-DerivedUserPrincipalName -ProvisioningRow $row -MappedProvisioningIdentity $mapped -TenantDomainSuffix 'contoso.com' -UpnExists { $false } } |
            Should -Throw -ExceptionType ([System.InvalidOperationException]) -PassThru |
            ForEach-Object { $_.Exception.Message } |
            Should -Match 'physical line 7'
    }

    It 'fails when CSV UserPrincipalName has no at-sign' {
        $row = [PSCustomObject]@{
            SourceLineNumber  = 9
            FirstName         = 'Bad'
            LastName          = 'Upn'
            Department        = 'Engineering'
            UserPrincipalName = 'not-an-email'
        }
        $mapped = New-TestMappedIdentity

        { Get-DerivedUserPrincipalName -ProvisioningRow $row -MappedProvisioningIdentity $mapped -TenantDomainSuffix 'contoso.com' -UpnExists { $false } } |
            Should -Throw -ExceptionType ([System.InvalidOperationException]) -PassThru |
            ForEach-Object { $_.Exception.Message } |
            Should -Match 'physical line 9'
    }

    It 'fails when CSV UserPrincipalName contains more than one at-sign' {
        $row = [PSCustomObject]@{
            SourceLineNumber  = 10
            FirstName         = 'Bad'
            LastName          = 'Upn'
            Department        = 'Engineering'
            UserPrincipalName = 'a@b@c'
        }
        $mapped = New-TestMappedIdentity

        { Get-DerivedUserPrincipalName -ProvisioningRow $row -MappedProvisioningIdentity $mapped -TenantDomainSuffix 'contoso.com' -UpnExists { $false } } |
            Should -Throw -ExceptionType ([System.InvalidOperationException])
    }
}
