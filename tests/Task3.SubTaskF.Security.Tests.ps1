<#
.SYNOPSIS
    Security regression tests for Task 3 Sub-task F (Import-ProvisioningCsv orchestration).

.DESCRIPTION
    Validates fail-closed pipeline behavior, safe error surfaces, path boundary handling,
    and absence of Graph or high-risk execution patterns in the public import cmdlet.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ModuleRoot = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    $script:ImportPath = Join-Path -Path $script:ModuleRoot -ChildPath 'Public/Import-ProvisioningCsv.ps1'
    $script:Psm1Path = Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

Describe 'Task 3 Sub-task F - Import-ProvisioningCsv security' {

    It 'does not use high-risk execution, network, or Graph cmdlets in the import script' {
        $text = Get-Content -LiteralPath $script:ImportPath -Raw
        $dangerousPatterns = @(
            '(?i)\bInvoke-Expression\b'
            '(?i)\biex\b'
            '(?i)\bInvoke-Command\b'
            '(?i)\bInvoke-WebRequest\b'
            '(?i)\bInvoke-RestMethod\b'
            '(?i)\bStart-Process\b'
            '(?i)\bImport-Csv\b'
            '(?i)\bConnect-MgGraph\b'
            '(?i)\bImport-Module\s+.*Microsoft\.Graph'
        )
        foreach ($pattern in $dangerousPatterns) {
            $text | Should -Not -Match $pattern
        }
    }

    It 'throws on invalid UTF-8 without emitting pipeline objects' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'invalid-utf8.csv'
        [System.IO.File]::WriteAllBytes($csvPath, [byte[]](0xC0, 0xAF, 0x0A, 0x46, 0x69, 0x72, 0x73, 0x74, 0x4E, 0x61, 0x6D, 0x65))

        $emitted = [System.Collections.Generic.List[object]]::new()
        $thrown = $null
        try {
            Import-ProvisioningCsv -Path $csvPath | ForEach-Object { $emitted.Add($_) | Out-Null }
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.Message | Should -Match 'UTF-8'
        $thrown.Exception.InnerException | Should -BeNullOrEmpty
        $emitted.Count | Should -Be 0
    }

    It 'throws when Path is a directory without emitting pipeline objects' {
        $directoryPath = Join-Path -Path $TestDrive -ChildPath 'csv-directory'
        New-Item -ItemType Directory -Path $directoryPath -Force | Out-Null

        $emitted = [System.Collections.Generic.List[object]]::new()
        $thrown = $null
        try {
            Import-ProvisioningCsv -Path $directoryPath | ForEach-Object { $emitted.Add($_) | Out-Null }
        }
        catch {
            $thrown = $_
        }

        $thrown | Should -Not -BeNullOrEmpty
        $emitted.Count | Should -Be 0
    }

    It 'throws on malformed CSV quoting without emitting pipeline objects' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'malformed-quote.csv'
        Set-Content -LiteralPath $csvPath -Value 'FirstName,LastName,Department' -Encoding utf8NoBOM
        Add-Content -LiteralPath $csvPath -Value 'Ada,"unclosed' -Encoding utf8NoBOM

        $emitted = [System.Collections.Generic.List[object]]::new()
        $thrown = $null
        try {
            Import-ProvisioningCsv -Path $csvPath | ForEach-Object { $emitted.Add($_) | Out-Null }
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.InnerException | Should -BeNullOrEmpty
        $emitted.Count | Should -Be 0
    }

    It 'does not leak other cell values when a required field is empty after trim' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'empty-required.csv'
        $sensitivePayload = 'SECRET_PAYLOAD_f91c0a3b'
        $content = @(
            'FirstName,LastName,Department'
            "$sensitivePayload,  ,Engineering"
        ) -join "`n"
        Set-Content -LiteralPath $csvPath -Value $content -Encoding utf8NoBOM

        $emitted = [System.Collections.Generic.List[object]]::new()
        $thrown = $null
        try {
            Import-ProvisioningCsv -Path $csvPath | ForEach-Object { $emitted.Add($_) | Out-Null }
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.Message | Should -Match 'LastName'
        $thrown.Exception.Message | Should -Not -Match $sensitivePayload
        $emitted.Count | Should -Be 0
    }
}
