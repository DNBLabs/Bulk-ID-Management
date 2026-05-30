<#
.SYNOPSIS
    Security regression tests for Task 3 Sub-task E (provisioning row materialization).

.DESCRIPTION
    Validates safe error surfaces, header map integrity, data record bounds,
    and absence of high-risk execution patterns.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ModuleRoot = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    $privateDir = Join-Path -Path $script:ModuleRoot -ChildPath 'Private'
    $constantsPath = Join-Path -Path $privateDir -ChildPath 'Csv/ProvisioningCsv.Constants.ps1'
    $script:MaterializerPath = Join-Path -Path $privateDir -ChildPath 'Csv/New-ProvisioningCsvRow.ps1'
    . $constantsPath
    . $script:MaterializerPath

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

Describe 'Task 3 Sub-task E - Get-ProvisioningCsvMaterializedRows security' {

    It 'does not use high-risk execution or network cmdlets in the materializer script' {
        $text = Get-Content -LiteralPath $script:MaterializerPath -Raw
        $dangerousPatterns = @(
            '(?i)\bInvoke-Expression\b'
            '(?i)\biex\b'
            '(?i)\bInvoke-Command\b'
            '(?i)\bInvoke-WebRequest\b'
            '(?i)\bInvoke-RestMethod\b'
            '(?i)\bStart-Process\b'
            '(?i)\bImport-Csv\b'
        )
        foreach ($pattern in $dangerousPatterns) {
            $text | Should -Not -Match $pattern
        }
    }

    It 'throws InvalidOperationException for empty required fields without leaking other cell values' {
        $sensitivePayload = 'SECRET_PAYLOAD_e8c41f02'
        $columnMap = @{
            FirstName  = 0
            LastName   = 1
            Department = 2
        }
        $dataRecords = @(
            (Build-TestLogicalRecord -StartLineNumber 3 -Fields @($sensitivePayload, '  ', 'Engineering'))
        )

        $thrown = $null
        try {
            Get-ProvisioningCsvMaterializedRows -DataLogicalRecords $dataRecords -HeaderColumnMap $columnMap
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.InnerException | Should -BeNullOrEmpty
        $thrown.Exception.Message | Should -Match 'LastName'
        $thrown.Exception.Message | Should -Not -Match $sensitivePayload
    }

    It 'throws when the header column map is missing a required canonical column' {
        $incompleteMap = @{
            FirstName  = 0
            Department = 1
        }
        $dataRecords = @(
            (Build-TestLogicalRecord -StartLineNumber 2 -Fields @('Ada', 'Lovelace', 'Engineering'))
        )

        $thrown = $null
        try {
            Get-ProvisioningCsvMaterializedRows -DataLogicalRecords $dataRecords -HeaderColumnMap $incompleteMap
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.Message | Should -Match 'LastName'
        $thrown.Exception.Message | Should -Match 'column map'
    }

    It 'rejects more data logical records than the maximum allowed with a safe message' {
        $columnMap = @{
            FirstName  = 0
            LastName   = 1
            Department = 2
        }
        $dataRecords = [object[]]::new($MaxProvisioningCsvDataRecordCount + 1)
        for ($index = 0; $index -lt $dataRecords.Length; $index++) {
            $dataRecords[$index] = (Build-TestLogicalRecord -StartLineNumber ($index + 2) -Fields @('Ada', 'Lovelace', 'Engineering'))
        }

        $thrown = $null
        try {
            Get-ProvisioningCsvMaterializedRows -DataLogicalRecords $dataRecords -HeaderColumnMap $columnMap
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.Message | Should -Match 'maximum'
        $thrown.Exception.InnerException | Should -BeNullOrEmpty
    }

    It 'throws a generic no-rows message without inner exception leakage' {
        $columnMap = @{
            FirstName  = 0
            LastName   = 1
            Department = 2
        }

        $thrown = $null
        try {
            Get-ProvisioningCsvMaterializedRows -DataLogicalRecords @() -HeaderColumnMap $columnMap
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.Message | Should -Match 'no provisioning rows'
        $thrown.Exception.InnerException | Should -BeNullOrEmpty
    }

    It 'does not export the row materializer on the module public surface' {
        $psm1Path = Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psm1'
        $resolvedPsm1 = Resolve-Path -LiteralPath $psm1Path
        $moduleInfo = Import-Module -Name $resolvedPsm1.Path -PassThru -Force
        try {
            { Get-Command -Module $moduleInfo -Name Get-ProvisioningCsvMaterializedRows -ErrorAction Stop } |
                Should -Throw
        }
        finally {
            Remove-Module -ModuleInfo $moduleInfo -Force -ErrorAction SilentlyContinue
        }
    }
}
