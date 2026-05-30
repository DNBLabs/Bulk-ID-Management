<#
.SYNOPSIS
    Security regression tests for Task 3 Sub-task B (Read-ProvisioningCsvUtf8).

.DESCRIPTION
    Validates path handling, file size bounds, and safe error surfaces at the CSV read boundary.
#>

BeforeAll {
    $repoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:PrivateDir = Join-Path -Path $repoRoot -ChildPath 'src/Modules/BulkIdentityManagement/Private'
    $utf8ReaderPath = Join-Path -Path $script:PrivateDir -ChildPath 'Csv/Read-ProvisioningCsvUtf8.ps1'
    . $utf8ReaderPath
}

Describe 'Task 3 Sub-task B - Read-ProvisioningCsvUtf8 security' {

    It 'rejects a directory path' {
        $directoryPath = Join-Path -Path $TestDrive -ChildPath 'not-a-file'
        New-Item -ItemType Directory -Path $directoryPath -Force | Out-Null
        { Read-ProvisioningCsvUtf8 -Path $directoryPath } | Should -Throw
    }

    It 'rejects files larger than the provisioning CSV size limit' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'too-large.csv'
        $stream = [System.IO.File]::Create($csvPath)
        try {
            $stream.SetLength($MaxProvisioningCsvFileBytes + 1)
        }
        finally {
            $stream.Dispose()
        }

        { Read-ProvisioningCsvUtf8 -Path $csvPath } | Should -Throw '*too large*'
    }

    It 'throws InvalidOperationException without wrapping path details for invalid UTF-8' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'bad-encoding.csv'
        [System.IO.File]::WriteAllBytes($csvPath, [byte[]](0xC0, 0xAF))

        $thrown = $null
        try {
            Read-ProvisioningCsvUtf8 -Path $csvPath
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.Message | Should -Be 'Provisioning CSV file is not valid UTF-8.'
        $thrown.Exception.InnerException | Should -BeNullOrEmpty
    }

    It 'accepts a file exactly at the module size limit when content is valid UTF-8' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'at-limit.csv'
        $stream = [System.IO.File]::Create($csvPath)
        try {
            $stream.SetLength($MaxProvisioningCsvFileBytes)
        }
        finally {
            $stream.Dispose()
        }

        { Read-ProvisioningCsvUtf8 -Path $csvPath } | Should -Not -Throw
    }
}
