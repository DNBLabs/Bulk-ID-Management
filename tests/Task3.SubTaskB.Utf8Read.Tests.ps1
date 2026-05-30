<#
.SYNOPSIS
    Pester tests for Implementation Plan Task 3 Sub-task B (UTF-8 CSV file read).

.DESCRIPTION
    Validates Read-ProvisioningCsvUtf8: UTF-8 with and without BOM, strict invalid-byte rejection,
    and physical line output suitable for downstream CSV parsing.
#>

BeforeAll {
    $repoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:PrivateDir = Join-Path -Path $repoRoot -ChildPath 'src/Modules/BulkIdentityManagement/Private'
    $utf8ReaderPath = Join-Path -Path $script:PrivateDir -ChildPath 'Csv/Read-ProvisioningCsvUtf8.ps1'
    if (-not (Test-Path -LiteralPath $utf8ReaderPath -PathType Leaf)) {
        throw "Expected UTF-8 reader script at: $utf8ReaderPath"
    }

    . $utf8ReaderPath
}

Describe 'Task 3 Sub-task B - Read-ProvisioningCsvUtf8' {

    It 'reads valid UTF-8 without BOM as physical lines' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'valid-no-bom.csv'
        $content = "FirstName,LastName,Department`nAda,Lovelace,Engineering"
        Set-Content -LiteralPath $csvPath -Value $content -Encoding utf8NoBOM

        $lines = Read-ProvisioningCsvUtf8 -Path $csvPath

        $lines.Count | Should -Be 2
        $lines[0] | Should -BeExactly 'FirstName,LastName,Department'
        $lines[1] | Should -BeExactly 'Ada,Lovelace,Engineering'
    }

    It 'reads UTF-8 with BOM and does not include BOM in the first line' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'valid-with-bom.csv'
        $content = "FirstName,LastName,Department`r`nAda,Lovelace,Engineering"
        $utf8WithBom = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($csvPath, $content, $utf8WithBom)

        $lines = Read-ProvisioningCsvUtf8 -Path $csvPath

        $lines[0].StartsWith([char]0xFEFF) | Should -BeFalse
        $lines[0] | Should -BeExactly 'FirstName,LastName,Department'
    }

    It 'throws a terminating encoding error when bytes are not valid UTF-8' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'invalid-utf8.csv'
        [System.IO.File]::WriteAllBytes($csvPath, [byte[]](0xFF, 0xFE, 0x80, 0x81))

        { Read-ProvisioningCsvUtf8 -Path $csvPath } | Should -Throw '*UTF-8*'
    }

    It 'throws when the file path does not exist' {
        $missingPath = Join-Path -Path $TestDrive -ChildPath 'does-not-exist.csv'
        { Read-ProvisioningCsvUtf8 -Path $missingPath } | Should -Throw
    }

    It 'returns no lines for an empty file' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'empty.csv'
        Set-Content -LiteralPath $csvPath -Value '' -Encoding utf8NoBOM -NoNewline

        $lines = Read-ProvisioningCsvUtf8 -Path $csvPath

        $lines | Should -Be @()
    }

    It 'returns no lines for a UTF-8 BOM-only file' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'bom-only.csv'
        [System.IO.File]::WriteAllBytes($csvPath, [byte[]](0xEF, 0xBB, 0xBF))

        $lines = Read-ProvisioningCsvUtf8 -Path $csvPath

        $lines.Count | Should -Be 0
    }
}
