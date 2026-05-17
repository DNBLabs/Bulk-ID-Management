<#
.SYNOPSIS
    Pester tests for Task 4 name mapping via Get-MappedProvisioningIdentity.

.DESCRIPTION
    Asserts GivenName, Surname, and DisplayName on mapped provisioning identity objects.
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

    $script:eAcute = [char]0x00E9
    $script:iAcute = [char]0x00ED

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

Describe 'Task 4 - name mapping via Get-MappedProvisioningIdentity' {

    It 'maps a minimal row to default GivenName, Surname, DisplayName, and derived MailNickname' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName = 'Ada'
            LastName  = 'Lovelace'
        }

        $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row

        $mapped.GivenName | Should -Be 'Ada'
        $mapped.Surname | Should -Be 'Lovelace'
        $mapped.DisplayName | Should -Be 'Ada Lovelace'
        $mapped.MailNickname | Should -Be 'ada.lovelace'
        $mapped.SourceLineNumber | Should -Be 2
    }

    It 'preserves diacritics on GivenName, Surname, and DisplayName' {
        $firstName = "Jos$($script:eAcute)"
        $lastName = "Garc$($script:iAcute)a"
        $row = New-TestProvisioningRow -Properties @{
            FirstName = $firstName
            LastName  = $lastName
        }

        $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row

        $mapped.GivenName | Should -Be $firstName
        $mapped.Surname | Should -Be $lastName
        $mapped.DisplayName | Should -Be "$firstName $lastName"
    }

    It 'collapses internal whitespace in mapped name fields' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName = 'Mary  Jane'
            LastName  = '  Watson  '
        }

        $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row

        $mapped.GivenName | Should -Be 'Mary Jane'
        $mapped.Surname | Should -Be 'Watson'
        $mapped.DisplayName | Should -Be 'Mary Jane Watson'
    }

    It 'applies GivenName override while DisplayName default uses FirstName and LastName' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName = 'Robert'
            LastName  = 'Smith'
            GivenName = 'Bob'
        }

        $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row

        $mapped.GivenName | Should -Be 'Bob'
        $mapped.Surname | Should -Be 'Smith'
        $mapped.DisplayName | Should -Be 'Robert Smith'
        $mapped.MailNickname | Should -Be 'bob.smith'
    }

    It 'applies Surname override when present on the row' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName = 'Ada'
            LastName  = 'Lovelace'
            Surname   = 'King'
        }

        $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row

        $mapped.Surname | Should -Be 'King'
        $mapped.MailNickname | Should -Be 'ada.king'
    }

    It 'applies DisplayName override when present on the row' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName  = 'Ada'
            LastName   = 'Lovelace'
            DisplayName = 'Countess Ada'
        }

        $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row

        $mapped.DisplayName | Should -Be 'Countess Ada'
        $mapped.MailNickname | Should -Be 'ada.lovelace'
    }

    It 'does not mutate the input provisioning row' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName = 'Ada'
            LastName  = 'Lovelace'
            GivenName = 'Bob'
        }

        $before = [ordered]@{}
        foreach ($property in $row.PSObject.Properties) {
            $before[$property.Name] = $property.Value
        }

        $null = Get-MappedProvisioningIdentity -ProvisioningRow $row

        foreach ($propertyName in $before.Keys) {
            $row.$propertyName | Should -BeExactly $before[$propertyName]
        }
    }
}
