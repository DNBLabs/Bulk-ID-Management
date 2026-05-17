<#
.SYNOPSIS
    Pester failure scenarios for Task 4 Get-MappedProvisioningIdentity.

.DESCRIPTION
    Invalid MailNickname and malformed provisioning row inputs. Imports root script module only.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ModuleRoot = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    $script:Psm1Path = Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop

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

Describe 'Task 4 - Get-MappedProvisioningIdentity failures' {

    It 'throws InvalidOperationException when MailNickname normalizes to empty' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName    = 'Ada'
            LastName     = 'Lovelace'
            MailNickname = '!!!'
            SourceLineNumber = 5
        }

        { Get-MappedProvisioningIdentity -ProvisioningRow $row } |
            Should -Throw -ExceptionType ([System.InvalidOperationException]) -PassThru |
            ForEach-Object { $_.Exception.Message } |
            Should -Match 'physical line 5'
    }

    It 'throws ArgumentException when required row properties are missing' {
        $row = [PSCustomObject]@{
            FirstName = 'Ada'
            LastName  = 'Lovelace'
        }

        { Get-MappedProvisioningIdentity -ProvisioningRow $row } |
            Should -Throw -ExceptionType ([System.ArgumentException])
    }

    It 'throws InvalidOperationException when derived nickname has no letters' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName = '***'
            LastName  = '...'
            SourceLineNumber = 7
        }

        { Get-MappedProvisioningIdentity -ProvisioningRow $row } |
            Should -Throw -ExceptionType ([System.InvalidOperationException]) -PassThru |
            ForEach-Object { $_.Exception.Message } |
            Should -Match 'physical line 7'
    }
}
