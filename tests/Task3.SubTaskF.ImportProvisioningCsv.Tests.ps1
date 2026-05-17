<#
.SYNOPSIS
    Pester tests for Implementation Plan Task 3 Sub-task F (Import-ProvisioningCsv orchestration).

.DESCRIPTION
    Validates end-to-end CSV import orchestration: pipeline output on success, terminating
    failures with no emitted rows, and missing-file handling.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ModuleRoot = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    $privateDir = Join-Path -Path $script:ModuleRoot -ChildPath 'Private'
    $importPath = Join-Path -Path $script:ModuleRoot -ChildPath 'Public/Import-ProvisioningCsv.ps1'
    if (-not (Test-Path -LiteralPath $importPath -PathType Leaf)) {
        throw "Expected Import-ProvisioningCsv script at: $importPath"
    }

    Get-ChildItem -LiteralPath $privateDir -Filter '*.ps1' -File |
        Sort-Object -Property Name |
        ForEach-Object { . $_.FullName }

    . $importPath
}

Describe 'Task 3 Sub-task F - Import-ProvisioningCsv' {

    It 'writes materialized provisioning rows to the pipeline in file order' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'valid-two-rows.csv'
        $content = @(
            'FirstName,LastName,Department'
            'Ada,Lovelace,Engineering'
            'Grace,Hopper,IT'
        ) -join "`n"
        Set-Content -LiteralPath $csvPath -Value $content -Encoding utf8NoBOM

        $rows = @(Import-ProvisioningCsv -Path $csvPath)

        $rows.Count | Should -Be 2
        $rows[0].FirstName | Should -Be 'Ada'
        $rows[0].SourceLineNumber | Should -Be 2
        $rows[1].FirstName | Should -Be 'Grace'
        $rows[1].SourceLineNumber | Should -Be 3
    }

    It 'throws on validation failure without emitting pipeline objects' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'bad-header.csv'
        Set-Content -LiteralPath $csvPath -Value 'FirstName,Department' -Encoding utf8NoBOM

        $emitted = [System.Collections.Generic.List[object]]::new()
        $thrown = $null
        try {
            Import-ProvisioningCsv -Path $csvPath | ForEach-Object { $emitted.Add($_) | Out-Null }
        }
        catch {
            $thrown = $_
        }

        $thrown | Should -Not -BeNullOrEmpty
        $emitted.Count | Should -Be 0
    }

    It 'throws when the CSV file path does not exist' {
        $missingPath = Join-Path -Path $TestDrive -ChildPath 'does-not-exist.csv'

        $emitted = [System.Collections.Generic.List[object]]::new()
        $thrown = $null
        try {
            Import-ProvisioningCsv -Path $missingPath | ForEach-Object { $emitted.Add($_) | Out-Null }
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.IO.FileNotFoundException])
        $emitted.Count | Should -Be 0
    }
}
