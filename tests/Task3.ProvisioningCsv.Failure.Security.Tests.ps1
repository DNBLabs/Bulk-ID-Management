<#
.SYNOPSIS
    Security regression tests for Task 3 Sub-task I (Import-ProvisioningCsv failure path).

.DESCRIPTION
    Validates fail-closed pipeline behavior on contract violations, safe error surfaces
    without inner-exception or cross-cell leakage, and module import without Graph manifest.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ModuleRoot = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    $script:Psm1Path = Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psm1'
    $script:FailureTestsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Task3.ProvisioningCsv.Failure.Tests.ps1'
    $script:MaxProvisioningCsvFileBytes = 10MB

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

Describe 'Task 3 Sub-task I - Import-ProvisioningCsv failure path security' {

    It 'loads the module from the root script module path without importing the manifest' {
        $text = Get-Content -LiteralPath $script:FailureTestsPath -Raw
        $text | Should -Match 'BulkIdentityManagement\.psm1'
        $text | Should -Not -Match 'BulkIdentityManagement\.psd1'
    }

    It 'throws InvalidOperationException for invalid UTF-8 without inner exception leakage or pipeline output' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'invalid-utf8-security.csv'
        [System.IO.File]::WriteAllBytes($csvPath, [byte[]](0xC0, 0xAF, 0x0A, 0x46, 0x69, 0x72, 0x73, 0x74))

        $result = Invoke-ImportProvisioningCsvExpectFailure -CsvPath $csvPath

        $result.Thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $result.Thrown.Exception.Message | Should -Be 'Provisioning CSV file is not valid UTF-8.'
        $result.Thrown.Exception.InnerException | Should -BeNullOrEmpty
        $result.EmittedCount | Should -Be 0
    }

    It 'throws on malformed CSV quoting without inner exception leakage or pipeline output' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'malformed-quote-security.csv'
        $content = @(
            'FirstName,LastName,Department'
            'Ada,"unclosed'
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $result = Invoke-ImportProvisioningCsvExpectFailure -CsvPath $csvPath

        $result.Thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $result.Thrown.Exception.Message | Should -Match 'Malformed provisioning CSV quoting'
        $result.Thrown.Exception.InnerException | Should -BeNullOrEmpty
        $result.EmittedCount | Should -Be 0
    }

    It 'does not leak other cell values when a required field is empty after trim' {
        $sensitivePayload = 'SECRET_PAYLOAD_3i_f8c41e90'
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'empty-required-security.csv'
        $content = @(
            'FirstName,LastName,Department'
            "$sensitivePayload,  ,Engineering"
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $result = Invoke-ImportProvisioningCsvExpectFailure -CsvPath $csvPath

        $result.Thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $result.Thrown.Exception.Message | Should -Match 'LastName'
        $result.Thrown.Exception.Message | Should -Not -Match $sensitivePayload
        $result.Thrown.Exception.InnerException | Should -BeNullOrEmpty
        $result.EmittedCount | Should -Be 0
    }

    It 'does not echo data-row cell values in duplicate-header failure messages' {
        $sensitivePayload = 'SECRET_PAYLOAD_3i_a2d7b501'
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'duplicate-header-security.csv'
        $content = @(
            'FirstName,LastName,Department,Department'
            "$sensitivePayload,Lovelace,Engineering,IT"
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $result = Invoke-ImportProvisioningCsvExpectFailure -CsvPath $csvPath

        $result.Thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $result.Thrown.Exception.Message | Should -Match 'Department'
        $result.Thrown.Exception.Message | Should -Match 'Duplicate'
        $result.Thrown.Exception.Message | Should -Not -Match $sensitivePayload
        $result.EmittedCount | Should -Be 0
    }

    It 'fails row validation on script-like cell text without emitting pipeline objects' {
        $literalPayload = "Invoke-Expression 'evil'"
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'script-like-failure.csv'
        $content = @(
            'FirstName,LastName,Department'
            "$literalPayload,  ,Engineering"
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $result = Invoke-ImportProvisioningCsvExpectFailure -CsvPath $csvPath

        $result.Thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $result.Thrown.Exception.Message | Should -Match 'LastName'
        $result.Thrown.Exception.Message | Should -Not -Match $literalPayload
        $result.EmittedCount | Should -Be 0
    }

    It 'throws when the CSV file exceeds the size limit without emitting pipeline objects' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'oversized-failure.csv'
        $stream = [System.IO.File]::Create($csvPath)
        try {
            $stream.SetLength($script:MaxProvisioningCsvFileBytes + 1)
        }
        finally {
            $stream.Dispose()
        }

        $result = Invoke-ImportProvisioningCsvExpectFailure -CsvPath $csvPath

        $result.Thrown | Should -Not -BeNullOrEmpty
        $result.Thrown.Exception.Message | Should -Match 'too large'
        $result.Thrown.Exception.InnerException | Should -BeNullOrEmpty
        $result.EmittedCount | Should -Be 0
    }

    It 'uses a generic no-rows message for header-only files without leaking unknown header names' {
        $unknownHeaderName = 'ClientSecret'
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'header-only-security.csv'
        $content = "FirstName,LastName,Department,$unknownHeaderName"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $result = Invoke-ImportProvisioningCsvExpectFailure -CsvPath $csvPath

        $result.Thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $result.Thrown.Exception.Message | Should -Be 'The CSV file contains no provisioning rows.'
        $result.Thrown.Exception.Message | Should -Not -Match $unknownHeaderName
        $result.EmittedCount | Should -Be 0
    }
}
