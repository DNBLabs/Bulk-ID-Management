<#
.SYNOPSIS
    Pester tests for Task 4 module export and Import-to-Map integration.

.DESCRIPTION
    Validates FunctionsToExport and a minimal Import-ProvisioningCsv to Get-MappedProvisioningIdentity path.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ModuleRoot = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    $script:Psm1Path = Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psm1'
    $script:Psd1Path = Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psd1'
    $script:eAcute = [char]0x00E9
    $script:iAcute = [char]0x00ED
}

Describe 'Task 4 Sub-task I - module export and integration' {

    It 'lists Get-MappedProvisioningIdentity in FunctionsToExport' {
        $data = Import-PowerShellDataFile -Path $script:Psd1Path
        @($data.FunctionsToExport) | Should -Contain 'Get-MappedProvisioningIdentity'
        @($data.FunctionsToExport) | Should -Contain 'Import-ProvisioningCsv'
    }

    It 'exposes Get-MappedProvisioningIdentity after importing the root module' {
        Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
        try {
            Get-Command -Name Get-MappedProvisioningIdentity -CommandType Function -ErrorAction Stop |
                Should -Not -BeNullOrEmpty
        }
        finally {
            Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
        }
    }

    It 'maps the first row from Import-ProvisioningCsv with accents preserved on names' {
        Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
        try {
            $csvPath = Join-Path -Path $TestDrive -ChildPath 'accent.csv'
            $firstName = "Jos$($script:eAcute)"
            $lastName = "Garc$($script:iAcute)a"
            $content = @(
                'FirstName,LastName,Department'
                "$firstName,$lastName,Engineering"
            ) -join "`n"
            Set-Content -LiteralPath $csvPath -Value $content -Encoding utf8NoBOM

            $row = (Import-ProvisioningCsv -Path $csvPath | Select-Object -First 1)
            $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row

            $mapped.GivenName | Should -Be $firstName
            $mapped.MailNickname | Should -Be 'jose.garcia'
        }
        finally {
            Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
        }
    }

    It 'does not reference Microsoft Graph in Task 4 source scripts' {
        $paths = @(
            (Join-Path -Path $script:ModuleRoot -ChildPath 'Public/Get-MappedProvisioningIdentity.ps1')
            (Join-Path -Path $script:ModuleRoot -ChildPath 'Private/Format-ProvisioningIdentityNamePart.ps1')
            (Join-Path -Path $script:ModuleRoot -ChildPath 'Private/Get-ProvisioningNameMappingFromRow.ps1')
            (Join-Path -Path $script:ModuleRoot -ChildPath 'Private/Get-NormalizedProvisioningMailNickname.ps1')
            (Join-Path -Path $script:ModuleRoot -ChildPath 'Private/ProvisioningIdentity.Constants.ps1')
            (Join-Path -Path $script:ModuleRoot -ChildPath 'Private/Test-ProvisioningIdentityRowBoundary.ps1')
        )

        foreach ($path in $paths) {
            Test-Path -LiteralPath $path -PathType Leaf | Should -BeTrue
            $text = Get-Content -LiteralPath $path -Raw
            $text | Should -Not -Match 'Connect-MgGraph'
            $text | Should -Not -Match 'Import-Module\s+Microsoft\.Graph'
        }
    }
}
