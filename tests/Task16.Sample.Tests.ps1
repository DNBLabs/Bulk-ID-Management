<#
.SYNOPSIS
    Pester tests for Task 16 committed provisioning sample CSV.

.DESCRIPTION
    Verifies the repository sample is minimal (core columns), uses fictional names only,
    and imports through the public Import-ProvisioningCsv contract without tenant identifiers.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:SamplePath = Join-Path -Path $script:RepoRoot -ChildPath 'samples/provisioning-sample.csv'
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 16 - provisioning sample CSV' {

    It 'imports the committed sample through Import-ProvisioningCsv with three provisioning rows' {
        Test-Path -LiteralPath $script:SamplePath -PathType Leaf | Should -BeTrue

        $rows = Import-ProvisioningCsv -Path $script:SamplePath
        @($rows).Count | Should -Be 3
        $rows[0].FirstName | Should -Be 'Ada'
        $rows[0].LastName | Should -Be 'Lovelace'
        $rows[1].Department | Should -Be 'IT'
    }

    It 'uses only required v1 header columns in the committed sample' {
        $header = (Get-Content -LiteralPath $script:SamplePath -TotalCount 1)
        $header | Should -Be 'FirstName,LastName,Department'
    }

    It 'does not embed real tenant identifiers in the sample file' {
        $raw = Get-Content -LiteralPath $script:SamplePath -Raw
        $raw | Should -Not -Match '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
        $raw | Should -Not -Match '@[a-z0-9.-]+\.(onmicrosoft|microsoft)\.com'
    }
}
