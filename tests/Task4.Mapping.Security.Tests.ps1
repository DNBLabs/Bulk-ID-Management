<#
.SYNOPSIS
    Security regression tests for Task 4 Get-MappedProvisioningIdentity.

.DESCRIPTION
    Validates fail-closed behavior, safe error surfaces, bounded untrusted string handling,
    output charset constraints on MailNickname, and absence of Graph or high-risk patterns.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ModuleRoot = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    $script:MapPath = Join-Path -Path $script:ModuleRoot -ChildPath 'Public/Get-MappedProvisioningIdentity.ps1'
    $script:MaxMailNicknameLength = 64
    $script:MaxNamePartLength = 64
    $script:MaxDisplayNameLength = 256
    $script:MaxNicknameInputLength = 512

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

    function script:Invoke-MapExpectFailure {
        param(
            [AllowNull()]
            [object] $Row
        )

        $emitted = $null
        $thrown = $null
        try {
            $emitted = Get-MappedProvisioningIdentity -ProvisioningRow $Row
        }
        catch {
            $thrown = $_
        }

        return [PSCustomObject]@{
            Thrown  = $thrown
            Emitted = $emitted
        }
    }
}

Describe 'Task 4 - Get-MappedProvisioningIdentity security' {

    It 'does not use high-risk execution, network, or Graph cmdlets in mapping scripts' {
        $paths = @(
            $script:MapPath
            (Join-Path -Path $script:ModuleRoot -ChildPath 'Private/Identity/Format-ProvisioningIdentityNamePart.ps1')
            (Join-Path -Path $script:ModuleRoot -ChildPath 'Private/Identity/Get-ProvisioningNameMappingFromRow.ps1')
            (Join-Path -Path $script:ModuleRoot -ChildPath 'Private/Identity/Get-NormalizedProvisioningMailNickname.ps1')
            (Join-Path -Path $script:ModuleRoot -ChildPath 'Private/Identity/ProvisioningIdentity.Constants.ps1')
            (Join-Path -Path $script:ModuleRoot -ChildPath 'Private/Identity/Test-ProvisioningIdentityRowBoundary.ps1')
        )

        $dangerousPatterns = @(
            '(?i)\bInvoke-Expression\b'
            '(?i)\biex\b'
            '(?i)\bInvoke-Command\b'
            '(?i)\bInvoke-WebRequest\b'
            '(?i)\bInvoke-RestMethod\b'
            '(?i)\bStart-Process\b'
            '(?i)\bConnect-MgGraph\b'
            '(?i)\bImport-Module\s+.*Microsoft\.Graph'
        )

        foreach ($path in $paths) {
            Test-Path -LiteralPath $path -PathType Leaf | Should -BeTrue
            $text = Get-Content -LiteralPath $path -Raw
            foreach ($pattern in $dangerousPatterns) {
                $text | Should -Not -Match $pattern
            }
        }
    }

    It 'throws ArgumentException for a null provisioning row without returning output' {
        $result = Invoke-MapExpectFailure -Row $null
        $result.Thrown.Exception | Should -BeOfType ([System.ArgumentException])
        $result.Emitted | Should -BeNullOrEmpty
    }

    It 'does not echo untrusted cell content in MailNickname failure messages' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName    = 'Ada'
            LastName     = 'Lovelace'
            MailNickname = '!!!'
            SourceLineNumber = 9
        }

        $result = Invoke-MapExpectFailure -Row $row
        $result.Thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $result.Thrown.Exception.Message | Should -Match 'physical line 9'
        $result.Thrown.Exception.Message | Should -Not -Match '!!!'
        $result.Thrown.Exception.InnerException | Should -BeNullOrEmpty
    }

    It 'throws when MailNickname input exceeds the maximum bounded length' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName    = 'Ada'
            LastName     = 'Lovelace'
            MailNickname = ('a' * ($script:MaxNicknameInputLength + 1))
        }

        $result = Invoke-MapExpectFailure -Row $row
        $result.Thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $result.Emitted | Should -BeNullOrEmpty
    }

    It 'throws when a mapped name field exceeds Entra-aligned maximum length' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName = ('A' * ($script:MaxNamePartLength + 1))
            LastName  = 'Lovelace'
        }

        $result = Invoke-MapExpectFailure -Row $row
        $result.Thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $result.Emitted | Should -BeNullOrEmpty
    }

    It 'returns MailNickname containing only the safe charset' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName = "Jean`u{200B}-Luc"
            LastName  = 'Picard'
        }

        $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row
        $mapped.MailNickname | Should -Match '^[a-z0-9.-]+$'
        $mapped.MailNickname.Length | Should -BeLessOrEqual $script:MaxMailNicknameLength
    }

    It 'returns mapped name fields within Entra-aligned length limits on success' {
        $row = New-TestProvisioningRow -Properties @{
            FirstName = 'Ada'
            LastName  = 'Lovelace'
        }

        $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row
        $mapped.GivenName.Length | Should -BeLessOrEqual $script:MaxNamePartLength
        $mapped.Surname.Length | Should -BeLessOrEqual $script:MaxNamePartLength
        $mapped.DisplayName.Length | Should -BeLessOrEqual $script:MaxDisplayNameLength
        $mapped.MailNickname.Length | Should -BeLessOrEqual $script:MaxMailNicknameLength
    }
}
