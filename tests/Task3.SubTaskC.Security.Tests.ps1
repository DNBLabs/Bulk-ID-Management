<#
.SYNOPSIS
    Security regression tests for Task 3 Sub-task C (logical CSV record parser).

.DESCRIPTION
    Validates comma-only parsing (no delimiter sniffing), safe malformed-parse errors,
    per-record field count bounds, and absence of high-risk execution patterns.
#>

BeforeAll {
    $repoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ModuleRoot = Join-Path -Path $repoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    $script:ParserPath = Join-Path -Path $script:ModuleRoot -ChildPath 'Private/Get-ProvisioningCsvRecord.ps1'
    if (-not (Test-Path -LiteralPath $script:ParserPath -PathType Leaf)) {
        throw "Expected CSV logical record parser at: $script:ParserPath"
    }

    . $script:ParserPath
}

Describe 'Task 3 Sub-task C - Get-ProvisioningCsvLogicalRecords security' {

    It 'does not use high-risk execution or network cmdlets in the parser script' {
        $text = Get-Content -LiteralPath $script:ParserPath -Raw
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

    It 'does not treat semicolon as a field delimiter (comma only)' {
        $records = Get-ProvisioningCsvLogicalRecords -PhysicalLines @('FirstName;LastName;Department')

        $records.Count | Should -Be 1
        $records[0].Fields.Count | Should -Be 1
        $records[0].Fields[0] | Should -Be 'FirstName;LastName;Department'
    }

    It 'does not treat tab as a field delimiter (comma only)' {
        $records = Get-ProvisioningCsvLogicalRecords -PhysicalLines @("FirstName`tLastName`tDepartment")

        $records[0].Fields.Count | Should -Be 1
    }

    It 'throws InvalidOperationException for malformed quoting without inner exception or field content' {
        $sensitivePayload = 'SECRET_PAYLOAD_7f3a9c2e'
        $lines = @("Start,""$sensitivePayload")

        $thrown = $null
        try {
            Get-ProvisioningCsvLogicalRecords -PhysicalLines $lines
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.InnerException | Should -BeNullOrEmpty
        $thrown.Exception.Message | Should -Match 'Malformed provisioning CSV quoting'
        $thrown.Exception.Message | Should -Not -Match $sensitivePayload
    }

    It 'rejects a record that exceeds the maximum field count with a safe message citing the start line' {
        $commaCount = $MaxProvisioningCsvFieldsPerRecord
        $line = (',' * $commaCount) + 'extra'
        $lines = @('FirstName,LastName,Department', $line)

        $thrown = $null
        try {
            Get-ProvisioningCsvLogicalRecords -PhysicalLines $lines
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.Message | Should -Match 'maximum'
        $thrown.Exception.Message | Should -Match 'line 2'
        $thrown.Exception.InnerException | Should -BeNullOrEmpty
    }

    It 'does not export the logical record parser on the module public surface' {
        $psm1Path = Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psm1'
        $resolvedPsm1 = Resolve-Path -LiteralPath $psm1Path
        $moduleInfo = Import-Module -Name $resolvedPsm1.Path -PassThru -Force
        try {
            { Get-Command -Module $moduleInfo -Name Get-ProvisioningCsvLogicalRecords -ErrorAction Stop } |
                Should -Throw
        }
        finally {
            Remove-Module -ModuleInfo $moduleInfo -Force -ErrorAction SilentlyContinue
        }
    }
}
