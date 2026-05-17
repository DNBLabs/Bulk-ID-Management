<#
.SYNOPSIS
    Pester tests for Implementation Plan Task 3 Sub-task E (provisioning row materialization).

.DESCRIPTION
    Validates Get-ProvisioningCsvMaterializedRows: required columns, skipped whitespace rows,
    optional property gating, and zero-row failure.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $privateDir = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/Private'
    $constantsPath = Join-Path -Path $privateDir -ChildPath 'ProvisioningCsv.Constants.ps1'
    $materializerPath = Join-Path -Path $privateDir -ChildPath 'New-ProvisioningCsvRow.ps1'
    if (-not (Test-Path -LiteralPath $constantsPath -PathType Leaf)) {
        throw "Expected constants script at: $constantsPath"
    }
    if (-not (Test-Path -LiteralPath $materializerPath -PathType Leaf)) {
        throw "Expected row materializer script at: $materializerPath"
    }

    . $constantsPath
    . $materializerPath

    function script:Build-TestLogicalRecord {
        param(
            [int] $StartLineNumber,
            [string[]] $Fields
        )

        return [PSCustomObject]@{
            StartLineNumber = $StartLineNumber
            Fields          = $Fields
        }
    }
}

Describe 'Task 3 Sub-task E - Get-ProvisioningCsvMaterializedRows' {

    It 'materializes a minimal three-column row with SourceLineNumber and trimmed core properties' {
        $columnMap = @{
            FirstName  = 0
            LastName   = 1
            Department = 2
        }
        $dataRecords = @(
            (Build-TestLogicalRecord -StartLineNumber 2 -Fields @(' Ada ', 'Lovelace', ' Engineering '))
        )

        $rows = Get-ProvisioningCsvMaterializedRows -DataLogicalRecords $dataRecords -HeaderColumnMap $columnMap

        $rows.Count | Should -Be 1
        $rows[0].SourceLineNumber | Should -Be 2
        $rows[0].FirstName | Should -Be 'Ada'
        $rows[0].LastName | Should -Be 'Lovelace'
        $rows[0].Department | Should -Be 'Engineering'
    }

    It 'skips a data row when every field is empty or whitespace after trim' {
        $columnMap = @{
            FirstName  = 0
            LastName   = 1
            Department = 2
        }
        $dataRecords = @(
            (Build-TestLogicalRecord -StartLineNumber 2 -Fields @('   ', "`t", ''))
            (Build-TestLogicalRecord -StartLineNumber 3 -Fields @('Grace', 'Hopper', 'IT'))
        )

        $rows = Get-ProvisioningCsvMaterializedRows -DataLogicalRecords $dataRecords -HeaderColumnMap $columnMap

        $rows.Count | Should -Be 1
        $rows[0].FirstName | Should -Be 'Grace'
    }

    It 'throws when no provisioning rows remain after skipping whitespace-only data rows' {
        $columnMap = @{
            FirstName  = 0
            LastName   = 1
            Department = 2
        }
        $dataRecords = @(
            (Build-TestLogicalRecord -StartLineNumber 2 -Fields @(' ', '', '  '))
        )

        { Get-ProvisioningCsvMaterializedRows -DataLogicalRecords $dataRecords -HeaderColumnMap $columnMap } |
            Should -Throw '*no provisioning rows*'
    }

    It 'throws when an empty collection of data logical records is supplied' {
        $columnMap = @{
            FirstName  = 0
            LastName   = 1
            Department = 2
        }

        { Get-ProvisioningCsvMaterializedRows -DataLogicalRecords @() -HeaderColumnMap $columnMap } |
            Should -Throw '*no provisioning rows*'
    }

    It 'omits an optional property when the header exists but the cell is blank after trim' {
        $columnMap = @{
            FirstName    = 0
            LastName     = 1
            Department   = 2
            MailNickname = 3
        }
        $dataRecords = @(
            (Build-TestLogicalRecord -StartLineNumber 2 -Fields @('Ada', 'Lovelace', 'Engineering', '   '))
        )

        $rows = Get-ProvisioningCsvMaterializedRows -DataLogicalRecords $dataRecords -HeaderColumnMap $columnMap

        $rows[0].PSObject.Properties.Name | Should -Not -Contain 'MailNickname'
        $rows[0].FirstName | Should -Be 'Ada'
    }

    It 'includes a trimmed optional property when the header exists and the cell has a value' {
        $columnMap = @{
            FirstName    = 0
            LastName     = 1
            Department   = 2
            MailNickname = 3
        }
        $dataRecords = @(
            (Build-TestLogicalRecord -StartLineNumber 2 -Fields @('Ada', 'Lovelace', 'Engineering', ' ada.lovelace '))
        )

        $rows = Get-ProvisioningCsvMaterializedRows -DataLogicalRecords $dataRecords -HeaderColumnMap $columnMap

        $rows[0].MailNickname | Should -Be 'ada.lovelace'
    }

    It 'throws when a required cell is empty after trim, citing the physical line number' {
        $columnMap = @{
            FirstName  = 0
            LastName   = 1
            Department = 2
        }
        $dataRecords = @(
            (Build-TestLogicalRecord -StartLineNumber 4 -Fields @('Ada', '  ', 'Engineering'))
        )

        $thrown = $null
        try {
            Get-ProvisioningCsvMaterializedRows -DataLogicalRecords $dataRecords -HeaderColumnMap $columnMap
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.Message | Should -Match 'LastName'
        $thrown.Exception.Message | Should -Match 'line 4'
    }
}
