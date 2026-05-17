<#
.SYNOPSIS
    Pester tests for Implementation Plan Task 3 Sub-task C (logical CSV record parser).

.DESCRIPTION
    Validates Get-ProvisioningCsvLogicalRecords: RFC-style comma parsing, start line numbers,
    and malformed quoting failures.
#>

BeforeAll {
    $repoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $parserPath = Join-Path -Path $repoRoot -ChildPath 'src/Modules/BulkIdentityManagement/Private/Get-ProvisioningCsvRecord.ps1'
    if (-not (Test-Path -LiteralPath $parserPath -PathType Leaf)) {
        throw "Expected CSV logical record parser at: $parserPath"
    }

    . $parserPath
}

Describe 'Task 3 Sub-task C - Get-ProvisioningCsvLogicalRecords' {

    It 'returns no records for empty physical line input' {
        $records = Get-ProvisioningCsvLogicalRecords -PhysicalLines @()
        $records | Should -Be @()
    }

    It 'parses unquoted fields on a single physical line' {
        $records = Get-ProvisioningCsvLogicalRecords -PhysicalLines @('FirstName,LastName,Department')

        $records.Count | Should -Be 1
        $records[0].StartLineNumber | Should -Be 1
        $records[0].Fields | Should -BeExactly @('FirstName', 'LastName', 'Department')
    }

    It 'parses multiple unquoted records across physical lines with correct start lines' {
        $lines = @(
            'Ada,Lovelace,Engineering'
            'Grace,Hopper,IT'
        )
        $records = Get-ProvisioningCsvLogicalRecords -PhysicalLines $lines

        $records.Count | Should -Be 2
        $records[0].StartLineNumber | Should -Be 1
        $records[0].Fields[0] | Should -Be 'Ada'
        $records[1].StartLineNumber | Should -Be 2
        $records[1].Fields[1] | Should -Be 'Hopper'
    }

    It 'parses a quoted field containing a comma' {
        $records = Get-ProvisioningCsvLogicalRecords -PhysicalLines @('"O''Brien, Jr",Lovelace,Engineering')

        $records[0].StartLineNumber | Should -Be 1
        $records[0].Fields[0] | Should -Be "O'Brien, Jr"
        $records[0].Fields[1] | Should -Be 'Lovelace'
    }

    It 'parses escaped double quotes inside a quoted field' {
        $records = Get-ProvisioningCsvLogicalRecords -PhysicalLines @('"He said ""Hi""",Name')

        $records[0].Fields[0] | Should -Be 'He said "Hi"'
        $records[0].Fields[1] | Should -Be 'Name'
    }

    It 'parses a quoted field that spans multiple physical lines' {
        $lines = @(
            '"O''Brien,'
            ' Jr",LastName'
        )
        $records = Get-ProvisioningCsvLogicalRecords -PhysicalLines $lines

        $records.Count | Should -Be 1
        $records[0].StartLineNumber | Should -Be 1
        $records[0].Fields[0] | Should -Be "O'Brien,`n Jr"
        $records[0].Fields[1] | Should -Be 'LastName'
    }

    It 'parses an empty physical line as one record with a single empty field' {
        $records = Get-ProvisioningCsvLogicalRecords -PhysicalLines @([string]::Empty)

        $records.Count | Should -Be 1
        $records[0].StartLineNumber | Should -Be 1
        $records[0].Fields.Count | Should -Be 1
        $records[0].Fields[0] | Should -Be ''
    }

    It 'accepts a record with exactly the maximum allowed field count' {
        $line = ',' * ($MaxProvisioningCsvFieldsPerRecord - 1)
        $records = Get-ProvisioningCsvLogicalRecords -PhysicalLines @($line)

        $records.Count | Should -Be 1
        $records[0].Fields.Count | Should -Be $MaxProvisioningCsvFieldsPerRecord
    }

    It 'throws InvalidOperationException when a quoted field is not closed, citing the record start line' {
        $lines = @(
            'FirstName,LastName,Department'
            'Start,"unclosed'
        )

        $thrown = $null
        try {
            Get-ProvisioningCsvLogicalRecords -PhysicalLines $lines
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.Message | Should -Match 'Malformed provisioning CSV quoting'
        $thrown.Exception.Message | Should -Match 'line 2'
    }

    It 'throws InvalidOperationException when characters appear after a closed quoted field' {
        $lines = @('FirstName,"Last"Name,Department')

        $thrown = $null
        try {
            Get-ProvisioningCsvLogicalRecords -PhysicalLines $lines
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.Message | Should -Match 'Malformed provisioning CSV quoting'
        $thrown.Exception.Message | Should -Match 'line 1'
    }
}
