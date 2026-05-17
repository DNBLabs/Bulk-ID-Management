<#
.SYNOPSIS
    Pester success scenarios for Task 3 Sub-task H (Import-ProvisioningCsv contract).

.DESCRIPTION
    End-to-end tests for observable provisioning row output: UTF-8 with BOM, optional column
    gating, quoted fields, unknown headers, trimming, SourceLineNumber, and row order.
    Imports the root script module only (no manifest Graph dependency).
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ModuleRoot = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    $script:Psm1Path = Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psm1'

    if (-not (Test-Path -LiteralPath $script:Psm1Path -PathType Leaf)) {
        throw "Expected module root script at: $script:Psm1Path"
    }

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

    function script:Write-ProvisioningCsvUtf8WithBom {
        param(
            [Parameter(Mandatory)]
            [string] $Path,

            [Parameter(Mandatory)]
            [string] $Content
        )

        $utf8WithBom = [System.Text.UTF8Encoding]::new($true)
        [System.IO.File]::WriteAllText($Path, $Content, $utf8WithBom)
    }

    function script:Import-ProvisioningCsvFromTestPath {
        param(
            [Parameter(Mandatory)]
            [string] $CsvPath
        )

        return @(Import-ProvisioningCsv -Path $CsvPath)
    }
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 3 Sub-task H - Import-ProvisioningCsv success scenarios' {

    It 'imports a minimal three-column CSV with required properties only' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'minimal.csv'
        $content = @(
            'FirstName,LastName,Department'
            'Ada,Lovelace,Engineering'
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $rows = Import-ProvisioningCsvFromTestPath -CsvPath $csvPath

        $rows.Count | Should -Be 1
        $rows[0].FirstName | Should -Be 'Ada'
        $rows[0].LastName | Should -Be 'Lovelace'
        $rows[0].Department | Should -Be 'Engineering'
        $rows[0].SourceLineNumber | Should -Be 2
        $rows[0].PSObject.Properties.Name | Should -BeExactly @(
            'SourceLineNumber'
            'FirstName'
            'LastName'
            'Department'
        )
    }

    It 'imports a UTF-8 file with BOM' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'with-bom.csv'
        $content = "FirstName,LastName,Department`r`nGrace,Hopper,IT"
        Write-ProvisioningCsvUtf8WithBom -Path $csvPath -Content $content

        $rows = Import-ProvisioningCsvFromTestPath -CsvPath $csvPath

        $rows.Count | Should -Be 1
        $rows[0].FirstName | Should -Be 'Grace'
        $rows[0].Department | Should -Be 'IT'
    }

    It 'trims leading and trailing whitespace on materialized values' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'trimmed.csv'
        $content = @(
            'FirstName,LastName,Department'
            '  Ada  ,  Lovelace  ,  Engineering  '
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $rows = Import-ProvisioningCsvFromTestPath -CsvPath $csvPath

        $rows[0].FirstName | Should -Be 'Ada'
        $rows[0].LastName | Should -Be 'Lovelace'
        $rows[0].Department | Should -Be 'Engineering'
    }

    It 'returns multiple rows in file order with SourceLineNumber on each row' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'multi-row.csv'
        $content = @(
            'FirstName,LastName,Department'
            'Ada,Lovelace,Engineering'
            'Grace,Hopper,IT'
            'Alan,Turing,Research'
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $rows = Import-ProvisioningCsvFromTestPath -CsvPath $csvPath

        $rows.Count | Should -Be 3
        $rows[0].FirstName | Should -Be 'Ada'
        $rows[0].SourceLineNumber | Should -Be 2
        $rows[1].FirstName | Should -Be 'Grace'
        $rows[1].SourceLineNumber | Should -Be 3
        $rows[2].FirstName | Should -Be 'Alan'
        $rows[2].SourceLineNumber | Should -Be 4
    }

    It 'parses a quoted field that contains a comma' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'quoted-comma.csv'
        $content = @(
            'FirstName,LastName,Department'
            '"O''Brien, Jr",Lovelace,Engineering'
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $rows = Import-ProvisioningCsvFromTestPath -CsvPath $csvPath

        $rows[0].FirstName | Should -Be "O'Brien, Jr"
        $rows[0].LastName | Should -Be 'Lovelace'
    }

    It 'includes optional properties when the header and non-empty cells are present' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'optional-present.csv'
        $content = @(
            'FirstName,LastName,Department,MailNickname,UserPrincipalName'
            'Ada,Lovelace,Engineering, ada.lovelace , ada@contoso.com '
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $rows = Import-ProvisioningCsvFromTestPath -CsvPath $csvPath

        $rows[0].MailNickname | Should -Be 'ada.lovelace'
        $rows[0].UserPrincipalName | Should -Be 'ada@contoso.com'
    }

    It 'omits optional properties when optional headers are not in the file' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'optional-absent.csv'
        $content = @(
            'FirstName,LastName,Department'
            'Ada,Lovelace,Engineering'
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $rows = Import-ProvisioningCsvFromTestPath -CsvPath $csvPath

        $rows[0].PSObject.Properties.Name | Should -Not -Contain 'MailNickname'
        $rows[0].PSObject.Properties.Name | Should -Not -Contain 'UserPrincipalName'
    }

    It 'omits an optional property when the header exists but the cell is blank after trim' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'optional-blank-cell.csv'
        $content = @(
            'FirstName,LastName,Department,MailNickname'
            'Ada,Lovelace,Engineering,   '
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $rows = Import-ProvisioningCsvFromTestPath -CsvPath $csvPath

        $rows[0].PSObject.Properties.Name | Should -Not -Contain 'MailNickname'
    }

    It 'ignores unknown header columns without adding properties to the row' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'unknown-column.csv'
        $content = @(
            'FirstName,LastName,Department,LegacyEmployeeId'
            'Ada,Lovelace,Engineering,99999'
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $rows = Import-ProvisioningCsvFromTestPath -CsvPath $csvPath

        $rows[0].PSObject.Properties.Name | Should -Not -Contain 'LegacyEmployeeId'
        $rows[0].FirstName | Should -Be 'Ada'
    }

    It 'skips whitespace-only data rows and preserves SourceLineNumber for remaining rows' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'skip-blank-row.csv'
        $content = @(
            'FirstName,LastName,Department'
            '   ,  ,   '
            'Grace,Hopper,IT'
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $rows = Import-ProvisioningCsvFromTestPath -CsvPath $csvPath

        $rows.Count | Should -Be 1
        $rows[0].FirstName | Should -Be 'Grace'
        $rows[0].SourceLineNumber | Should -Be 3
    }
}
