<#
.SYNOPSIS
    Security regression tests for Task 3 Sub-task H (Import-ProvisioningCsv success path).

.DESCRIPTION
    Validates that successful CSV imports keep a minimal row surface, do not expose
    unknown-column data on provisioning rows, treat cell text as data only, and enforce
    file size limits without emitting pipeline output on rejection.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ModuleRoot = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    $script:Psm1Path = Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psm1'
    $script:SuccessTestsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Task3.ProvisioningCsv.Success.Tests.ps1'
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
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 3 Sub-task H - Import-ProvisioningCsv success path security' {

    It 'loads the module from the root script module path without importing the manifest' {
        $text = Get-Content -LiteralPath $script:SuccessTestsPath -Raw
        $text | Should -Match 'BulkIdentityManagement\.psm1'
        $text | Should -Not -Match 'BulkIdentityManagement\.psd1'
    }

    It 'does not expose unknown-column cell values on materialized row properties' {
        $sensitivePayload = 'SECRET_PAYLOAD_3h_e4a91c02'
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'unknown-sensitive.csv'
        $content = @(
            'FirstName,LastName,Department,ClientSecret'
            "Ada,Lovelace,Engineering,$sensitivePayload"
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $rows = @(Import-ProvisioningCsv -Path $csvPath)

        $rows.Count | Should -Be 1
        $rows[0].PSObject.Properties.Name | Should -Not -Contain 'ClientSecret'
        foreach ($property in $rows[0].PSObject.Properties) {
            [string] $property.Value | Should -Not -Be $sensitivePayload
        }
    }

    It 'materializes script-like cell text as literal data without executing it' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'script-like-cell.csv'
        $literalPayload = "Invoke-Expression 'evil'"
        $content = @(
            'FirstName,LastName,Department'
            "$literalPayload,Lovelace,Engineering"
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $rows = @(Import-ProvisioningCsv -Path $csvPath)

        $rows[0].FirstName | Should -Be $literalPayload
    }

    It 'does not add file path or internal metadata properties to successful row objects' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'no-metadata.csv'
        $content = @(
            'FirstName,LastName,Department'
            'Ada,Lovelace,Engineering'
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $rows = @(Import-ProvisioningCsv -Path $csvPath)

        $rows[0].PSObject.Properties.Name | Should -BeExactly @(
            'SourceLineNumber'
            'FirstName'
            'LastName'
            'Department'
        )
    }

    It 'throws when the CSV file exceeds the size limit without emitting pipeline objects' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'oversized-success.csv'
        $stream = [System.IO.File]::Create($csvPath)
        try {
            $stream.SetLength($script:MaxProvisioningCsvFileBytes + 1)
        }
        finally {
            $stream.Dispose()
        }

        $emitted = [System.Collections.Generic.List[object]]::new()
        $thrown = $null
        try {
            Import-ProvisioningCsv -Path $csvPath | ForEach-Object { $emitted.Add($_) | Out-Null }
        }
        catch {
            $thrown = $_
        }

        $thrown | Should -Not -BeNullOrEmpty
        $thrown.Exception.Message | Should -Match 'too large'
        $emitted.Count | Should -Be 0
    }
}
