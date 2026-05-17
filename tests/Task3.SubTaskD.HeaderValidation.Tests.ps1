<#
.SYNOPSIS
    Pester tests for Implementation Plan Task 3 Sub-task D (header validation and column map).

.DESCRIPTION
    Validates Get-ProvisioningCsvHeaderColumnMap: required headers, case sensitivity,
    duplicate detection, trimmed matching, and unknown column exclusion.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $repoRoot = $script:RepoRoot
    $privateDir = Join-Path -Path $repoRoot -ChildPath 'src/Modules/BulkIdentityManagement/Private'
    $constantsPath = Join-Path -Path $privateDir -ChildPath 'ProvisioningCsv.Constants.ps1'
    $headerPath = Join-Path -Path $privateDir -ChildPath 'Test-ProvisioningCsvHeader.ps1'
    if (-not (Test-Path -LiteralPath $constantsPath -PathType Leaf)) {
        throw "Expected constants script at: $constantsPath"
    }
    if (-not (Test-Path -LiteralPath $headerPath -PathType Leaf)) {
        throw "Expected header validation script at: $headerPath"
    }

    . $constantsPath
    . $headerPath
}

Describe 'Task 3 Sub-task D - Get-ProvisioningCsvHeaderColumnMap' {

    It 'returns a column index map for a valid minimal header row' {
        $columnMap = Get-ProvisioningCsvHeaderColumnMap -HeaderFields @(
            'FirstName'
            'LastName'
            'Department'
        )

        $columnMap['FirstName'] | Should -Be 0
        $columnMap['LastName'] | Should -Be 1
        $columnMap['Department'] | Should -Be 2
        $columnMap.Count | Should -Be 3
    }

    It 'throws before data processing when a required header is missing' {
        $thrown = $null
        try {
            Get-ProvisioningCsvHeaderColumnMap -HeaderFields @('FirstName', 'Department')
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.Message | Should -Match 'LastName'
        $thrown.Exception.Message | Should -Match 'header'
    }

    It 'throws when a canonical header name is duplicated after trim' {
        $thrown = $null
        try {
            Get-ProvisioningCsvHeaderColumnMap -HeaderFields @(
                'FirstName'
                'LastName'
                'Department'
                'Department'
            )
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.Message | Should -Match 'Department'
        $thrown.Exception.Message | Should -Match 'duplicate'
    }

    It 'does not treat wrong-case header names as required columns' {
        $thrown = $null
        try {
            Get-ProvisioningCsvHeaderColumnMap -HeaderFields @(
                'firstname'
                'LastName'
                'Department'
            )
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.Message | Should -Match 'FirstName'
    }

    It 'omits unknown header columns from the column map' {
        $columnMap = Get-ProvisioningCsvHeaderColumnMap -HeaderFields @(
            'FirstName'
            'LastName'
            'Department'
            ' EmployeeId'
        )

        $columnMap.ContainsKey('EmployeeId') | Should -BeFalse
        $columnMap['Department'] | Should -Be 2
    }

    It 'matches canonical headers after trimming header cell whitespace' {
        $columnMap = Get-ProvisioningCsvHeaderColumnMap -HeaderFields @(
            'FirstName'
            'LastName'
            ' Department'
        )

        $columnMap['Department'] | Should -Be 2
    }

    It 'builds the column map from the first logical record produced by the CSV parser' {
        $parserPath = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/Private/Get-ProvisioningCsvRecord.ps1'
        . $parserPath

        $records = Get-ProvisioningCsvLogicalRecords -PhysicalLines @(
            'FirstName,LastName, Department'
            'Ada,Lovelace,Engineering'
        )
        $columnMap = Get-ProvisioningCsvHeaderColumnMap -HeaderFields $records[0].Fields -HeaderStartLineNumber $records[0].StartLineNumber

        $columnMap['Department'] | Should -Be 2
    }
}
