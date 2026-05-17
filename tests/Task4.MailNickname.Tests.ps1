<#
.SYNOPSIS
    Pester tests for Task 4 MailNickname normalization via Get-MappedProvisioningIdentity.

.DESCRIPTION
    Asserts derived and CSV-override MailNickname values. Imports root script module only.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ModuleRoot = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    $script:Psm1Path = Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop

    $script:eAcute = [char]0x00E9
    $script:iAcute = [char]0x00ED
    $script:oUmlaut = [char]0x00F6
    $script:sharpS = [char]0x00DF

    function script:New-TestProvisioningRow {
        param(
            [Parameter(Mandatory)]
            [hashtable] $Properties
        )

        if (-not $Properties.ContainsKey('SourceLineNumber')) {
            $Properties['SourceLineNumber'] = 2
        }

        if (-not $Properties.ContainsKey('Department')) {
            $Properties['Department'] = 'Engineering'
        }

        return [PSCustomObject] $Properties
    }
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 4 - MailNickname via Get-MappedProvisioningIdentity' {

    It 'derives maryjane.watson from a multi-word first name' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName = 'Mary Jane'
            LastName  = 'Watson'
        }

        $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row
        $mapped.MailNickname | Should -Be 'maryjane.watson'
    }

    It 'derives jean-luc.picard with hyphen retained' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName = 'Jean-Luc'
            LastName  = 'Picard'
        }

        $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row
        $mapped.MailNickname | Should -Be 'jean-luc.picard'
    }

    It 'strips apostrophe from O''Brien in MailNickname' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName = 'Anne'
            LastName  = "O'Brien"
        }

        $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row
        $mapped.MailNickname | Should -Be 'anne.obrien'
    }

    It 'derives jose.garcia with accents stripped from nickname only' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName = "Jos$($script:eAcute)"
            LastName  = "Garc$($script:iAcute)a"
        }

        $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row
        $mapped.MailNickname | Should -Be 'jose.garcia'
    }

    It 'derives bjorn.weiss with umlaut and eszett normalized' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName = "Bj$($script:oUmlaut)rn"
            LastName  = "Wei$($script:sharpS)"
        }

        $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row
        $mapped.MailNickname | Should -Be 'bjorn.weiss'
    }

    It 'normalizes CSV MailNickname override through the same pipeline' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName    = 'Ada'
            LastName     = 'Lovelace'
            MailNickname = 'ADA.LOVELACE'
        }

        $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row
        $mapped.MailNickname | Should -Be 'ada.lovelace'
    }

    It 'collapses repeated dots in CSV MailNickname override' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName    = 'John'
            LastName     = 'Smith'
            MailNickname = 'John..Smith'
        }

        $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row
        $mapped.MailNickname | Should -Be 'john.smith'
    }
}
