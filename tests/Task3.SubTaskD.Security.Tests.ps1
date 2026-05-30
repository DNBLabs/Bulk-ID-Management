<#
.SYNOPSIS
    Security regression tests for Task 3 Sub-task D (header validation).

.DESCRIPTION
    Validates safe error surfaces, case-sensitive canonical matching, duplicate detection
    for unknown columns, header field count bounds, and absence of high-risk patterns.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ModuleRoot = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    $privateDir = Join-Path -Path $script:ModuleRoot -ChildPath 'Private'
    $constantsPath = Join-Path -Path $privateDir -ChildPath 'Csv/ProvisioningCsv.Constants.ps1'
    $script:HeaderPath = Join-Path -Path $privateDir -ChildPath 'Csv/Test-ProvisioningCsvHeader.ps1'
    . $constantsPath
    . $script:HeaderPath
}

Describe 'Task 3 Sub-task D - Get-ProvisioningCsvHeaderColumnMap security' {

    It 'does not use high-risk execution or network cmdlets in the header validation script' {
        $text = Get-Content -LiteralPath $script:HeaderPath -Raw
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

    It 'throws InvalidOperationException for missing required headers without inner exception leakage' {
        $sensitivePayload = 'SECRET_PAYLOAD_b4e91d2a'
        $thrown = $null
        try {
            Get-ProvisioningCsvHeaderColumnMap -HeaderFields @(
                'FirstName'
                $sensitivePayload
                'Department'
            )
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.InnerException | Should -BeNullOrEmpty
        $thrown.Exception.Message | Should -Match 'LastName'
        $thrown.Exception.Message | Should -Not -Match $sensitivePayload
    }

    It 'rejects duplicate unknown header names after trim' {
        $thrown = $null
        try {
            Get-ProvisioningCsvHeaderColumnMap -HeaderFields @(
                'FirstName'
                'LastName'
                'Department'
                ' EmployeeId'
                'EmployeeId'
            )
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.Message | Should -Match 'EmployeeId'
        $thrown.Exception.Message | Should -Match 'duplicate'
    }

    It 'rejects headers that exceed the maximum field count with a safe message' {
        $headerFields = [string[]]::new($MaxProvisioningCsvHeaderFieldCount + 1)
        for ($index = 0; $index -lt $headerFields.Length; $index++) {
            $headerFields[$index] = "Column$index"
        }
        $headerFields[0] = 'FirstName'
        $headerFields[1] = 'LastName'
        $headerFields[2] = 'Department'

        $thrown = $null
        try {
            Get-ProvisioningCsvHeaderColumnMap -HeaderFields $headerFields
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.Message | Should -Match 'maximum'
        $thrown.Exception.InnerException | Should -BeNullOrEmpty
    }

    It 'does not export the header column map function on the module public surface' {
        $psm1Path = Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psm1'
        $resolvedPsm1 = Resolve-Path -LiteralPath $psm1Path
        $moduleInfo = Import-Module -Name $resolvedPsm1.Path -PassThru -Force
        try {
            { Get-Command -Module $moduleInfo -Name Get-ProvisioningCsvHeaderColumnMap -ErrorAction Stop } |
                Should -Throw
        }
        finally {
            Remove-Module -ModuleInfo $moduleInfo -Force -ErrorAction SilentlyContinue
        }
    }
}
