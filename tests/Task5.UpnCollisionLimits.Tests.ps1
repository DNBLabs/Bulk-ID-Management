<#
.SYNOPSIS
    Pester tests for Task 5 UPN collision caps and UpnExists propagation.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 5 - collision limits and UpnExists errors' {

    It 'fails when all candidates within MaximumUpnCandidates are taken' {
        $row = [PSCustomObject]@{
            SourceLineNumber = 4
            FirstName        = 'Jane'
            LastName         = 'Doe'
            Department       = 'Engineering'
        }
        $mapped = [PSCustomObject]@{
            SourceLineNumber = 4
            GivenName          = 'Jane'
            Surname            = 'Doe'
            DisplayName        = 'Jane Doe'
            MailNickname       = 'jane.doe'
        }

        $errorRecord = { Get-DerivedUserPrincipalName -ProvisioningRow $row -MappedProvisioningIdentity $mapped -TenantDomainSuffix 'contoso.com' -MaximumUpnCandidates 3 -UpnExists { $true } } |
            Should -Throw -ExceptionType ([System.InvalidOperationException]) -PassThru
        $errorRecord.Exception.Message | Should -Match 'physical line 4'
        $errorRecord.Exception.Message | Should -Match '3 attempts'
    }

    It 'tries only the base candidate when MaximumUpnCandidates is 1' {
        $row = [PSCustomObject]@{
            SourceLineNumber = 2
            FirstName        = 'Ada'
            LastName         = 'Lovelace'
            Department       = 'Engineering'
        }
        $mapped = [PSCustomObject]@{
            SourceLineNumber = 2
            GivenName          = 'Ada'
            Surname            = 'Lovelace'
            DisplayName        = 'Ada Lovelace'
            MailNickname       = 'ada.lovelace'
        }
        $probes = [System.Collections.Generic.List[string]]::new()

        { Get-DerivedUserPrincipalName -ProvisioningRow $row -MappedProvisioningIdentity $mapped -TenantDomainSuffix 'contoso.com' -MaximumUpnCandidates 1 -UpnExists { param($u) $probes.Add($u) | Out-Null; $true } } |
            Should -Throw

        $probes.Count | Should -Be 1
        $probes[0] | Should -Be 'ada.lovelace@contoso.com'
    }

    It 'propagates exceptions thrown by UpnExists unchanged' {
        $row = [PSCustomObject]@{
            SourceLineNumber = 2
            FirstName        = 'Ada'
            LastName         = 'Lovelace'
            Department       = 'Engineering'
        }
        $mapped = [PSCustomObject]@{
            SourceLineNumber = 2
            GivenName          = 'Ada'
            Surname            = 'Lovelace'
            DisplayName        = 'Ada Lovelace'
            MailNickname       = 'ada.lovelace'
        }

        { Get-DerivedUserPrincipalName -ProvisioningRow $row -MappedProvisioningIdentity $mapped -TenantDomainSuffix 'contoso.com' -UpnExists { throw 'graph down' } } |
            Should -Throw -ExpectedMessage 'graph down'
    }
}
