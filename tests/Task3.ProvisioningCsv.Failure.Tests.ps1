<#
.SYNOPSIS
    Pester failure scenarios for Task 3 Sub-task I (Import-ProvisioningCsv contract).

.DESCRIPTION
    End-to-end failure tests for Import-ProvisioningCsv: header contract violations,
    row validation, encoding and parse errors, and fail-closed pipeline behavior.
    Imports the root script module only (no manifest Graph dependency).
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ModuleRoot = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    $script:Psm1Path = Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psm1'

    if (-not (Test-Path -LiteralPath $script:Psm1Path -PathType Leaf)) {
        throw "Expected module root script at: $script:Psm1Path"
    }

    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop

    function script:Write-ProvisioningCsvUtf8NoBom {
        param(
            [Parameter(Mandatory)]
            [string] $Path,

            [Parameter(Mandatory)]
            [string] $Content
        )

        Set-Content -LiteralPath $Path -Value $Content -Encoding utf8NoBOM -NoNewline:$false
    }

    function script:Invoke-ImportProvisioningCsvExpectFailure {
        param(
            [Parameter(Mandatory)]
            [string] $CsvPath
        )

        $emitted = [System.Collections.Generic.List[object]]::new()
        $thrown = $null
        try {
            Import-ProvisioningCsv -Path $CsvPath | ForEach-Object { $emitted.Add($_) | Out-Null }
        }
        catch {
            $thrown = $_
        }

        return [PSCustomObject]@{
            Thrown       = $thrown
            EmittedCount = $emitted.Count
        }
    }
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 3 Sub-task I - Import-ProvisioningCsv failure scenarios' {

    It 'throws without pipeline output when a required header is missing' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'missing-header.csv'
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content 'FirstName,Department'

        $result = Invoke-ImportProvisioningCsvExpectFailure -CsvPath $csvPath

        $result.Thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $result.Thrown.Exception.Message | Should -Match 'LastName'
        $result.Thrown.Exception.Message | Should -Match 'header'
        $result.EmittedCount | Should -Be 0
    }

    It 'throws without pipeline output when a header name is duplicated after trim' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'duplicate-header.csv'
        $content = @(
            'FirstName,LastName,Department,Department'
            'Ada,Lovelace,Engineering,IT'
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $result = Invoke-ImportProvisioningCsvExpectFailure -CsvPath $csvPath

        $result.Thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $result.Thrown.Exception.Message | Should -Match 'Department'
        $result.Thrown.Exception.Message | Should -Match 'Duplicate'
        $result.EmittedCount | Should -Be 0
    }

    It 'throws without pipeline output when a required header uses the wrong case' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'wrong-case-header.csv'
        $content = @(
            'firstname,LastName,Department'
            'Ada,Lovelace,Engineering'
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $result = Invoke-ImportProvisioningCsvExpectFailure -CsvPath $csvPath

        $result.Thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $result.Thrown.Exception.Message | Should -Match 'FirstName'
        $result.EmittedCount | Should -Be 0
    }

    It 'throws without pipeline output when a required cell is empty, citing the physical line number' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'empty-required-cell.csv'
        $content = @(
            'FirstName,LastName,Department'
            'Ada,Lovelace,Engineering'
            'Grace,  ,IT'
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $result = Invoke-ImportProvisioningCsvExpectFailure -CsvPath $csvPath

        $result.Thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $result.Thrown.Exception.Message | Should -Match 'LastName'
        $result.Thrown.Exception.Message | Should -Match 'line 3'
        $result.EmittedCount | Should -Be 0
    }

    It 'throws without pipeline output when the file is not valid UTF-8' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'invalid-utf8.csv'
        [System.IO.File]::WriteAllBytes($csvPath, [byte[]](0xC0, 0xAF, 0x0A, 0x46, 0x69, 0x72, 0x73, 0x74))

        $result = Invoke-ImportProvisioningCsvExpectFailure -CsvPath $csvPath

        $result.Thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $result.Thrown.Exception.Message | Should -Match 'UTF-8'
        $result.EmittedCount | Should -Be 0
    }

    It 'throws without pipeline output when CSV quoting is malformed, citing the physical line number' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'malformed-quote.csv'
        $content = @(
            'FirstName,LastName,Department'
            'Ada,"unclosed'
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $result = Invoke-ImportProvisioningCsvExpectFailure -CsvPath $csvPath

        $result.Thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $result.Thrown.Exception.Message | Should -Match 'Malformed provisioning CSV quoting'
        $result.Thrown.Exception.Message | Should -Match 'line 2'
        $result.EmittedCount | Should -Be 0
    }

    It 'throws without pipeline output when semicolon-separated headers do not satisfy the comma contract' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'semicolon-separated.csv'
        $content = @(
            'FirstName;LastName;Department'
            'Ada;Lovelace;Engineering'
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $result = Invoke-ImportProvisioningCsvExpectFailure -CsvPath $csvPath

        $result.Thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $result.Thrown.Exception.Message | Should -Match 'Missing required provisioning CSV header'
        $result.EmittedCount | Should -Be 0
    }

    It 'throws without pipeline output for a header-only file with no provisioning rows' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'header-only.csv'
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content 'FirstName,LastName,Department'

        $result = Invoke-ImportProvisioningCsvExpectFailure -CsvPath $csvPath

        $result.Thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $result.Thrown.Exception.Message | Should -Match 'no provisioning rows'
        $result.EmittedCount | Should -Be 0
    }

    It 'throws without pipeline output when every data row is whitespace-only after trim' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'all-blank-rows.csv'
        $content = @(
            'FirstName,LastName,Department'
            '   ,  ,   '
            "`t, , "
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $result = Invoke-ImportProvisioningCsvExpectFailure -CsvPath $csvPath

        $result.Thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $result.Thrown.Exception.Message | Should -Match 'no provisioning rows'
        $result.EmittedCount | Should -Be 0
    }

    It 'throws without pipeline output when the file has no header row' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'empty-file.csv'
        [System.IO.File]::WriteAllBytes($csvPath, [byte[]]::new(0))

        $result = Invoke-ImportProvisioningCsvExpectFailure -CsvPath $csvPath

        $result.Thrown | Should -Not -BeNullOrEmpty
        $result.Thrown.Exception.Message | Should -Match 'header row'
        $result.EmittedCount | Should -Be 0
    }
}
