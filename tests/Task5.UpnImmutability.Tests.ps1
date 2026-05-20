<#
.SYNOPSIS
    Pester tests for Task 5 input immutability via Get-DerivedUserPrincipalName.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 5 - input immutability' {

    It 'does not mutate provisioning row or mapped provisioning identity' {
        $row = [PSCustomObject]@{
            SourceLineNumber = 3
            FirstName        = 'Ada'
            LastName         = 'Lovelace'
            Department       = 'Engineering'
        }
        $mapped = [PSCustomObject]@{
            SourceLineNumber = 3
            GivenName          = 'Ada'
            Surname            = 'Lovelace'
            DisplayName        = 'Ada Lovelace'
            MailNickname       = 'ada.lovelace'
        }
        $rowBefore = $row | ConvertTo-Json -Compress
        $mappedBefore = $mapped | ConvertTo-Json -Compress

        $null = Get-DerivedUserPrincipalName `
            -ProvisioningRow $row `
            -MappedProvisioningIdentity $mapped `
            -TenantDomainSuffix 'contoso.com' `
            -UpnExists { $false }

        ($row | ConvertTo-Json -Compress) | Should -Be $rowBefore
        ($mapped | ConvertTo-Json -Compress) | Should -Be $mappedBefore
    }
}
