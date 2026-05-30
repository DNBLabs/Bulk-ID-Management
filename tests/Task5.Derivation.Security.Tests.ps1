<#
.SYNOPSIS
    Security regression tests for Task 5 Get-DerivedUserPrincipalName.

.DESCRIPTION
    Validates fail-closed behavior, bounded untrusted input, safe error surfaces,
    collision cap limits, and absence of Graph or high-risk patterns.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ModuleRoot = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    $script:DerivePath = Join-Path -Path $script:ModuleRoot -ChildPath 'Public/Get-DerivedUserPrincipalName.ps1'
    $script:MaxUpnLength = 113
    $script:MaxDomainSuffixLength = 255
    $script:MaxUpnCandidates = 99

    Import-Module -Name (Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psm1') -Force -ErrorAction Stop

    function script:New-TestRow {
        param([hashtable] $Properties)
        if (-not $Properties.ContainsKey('SourceLineNumber')) { $Properties['SourceLineNumber'] = 2 }
        if (-not $Properties.ContainsKey('Department')) { $Properties['Department'] = 'Engineering' }
        [PSCustomObject] $Properties
    }

    function script:New-TestMapped {
        [PSCustomObject]@{
            SourceLineNumber = 2
            GivenName          = 'Ada'
            Surname            = 'Lovelace'
            DisplayName        = 'Ada Lovelace'
            MailNickname       = 'ada.lovelace'
        }
    }

    function script:Invoke-DeriveExpectFailure {
        param(
            [object] $Row,
            [object] $Mapped,
            [string] $TenantDomainSuffix = 'contoso.com',
            [scriptblock] $UpnExists = { $false }
        )

        $emitted = $null
        $thrown = $null
        try {
            $emitted = Get-DerivedUserPrincipalName `
                -ProvisioningRow $Row `
                -MappedProvisioningIdentity $Mapped `
                -TenantDomainSuffix $TenantDomainSuffix `
                -UpnExists $UpnExists
        }
        catch {
            $thrown = $_
        }

        [PSCustomObject]@{ Thrown = $thrown; Emitted = $emitted }
    }
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 5 - Get-DerivedUserPrincipalName security' {

    It 'does not use high-risk execution, network, or Graph cmdlets in derivation scripts' {
        $paths = @(
            $script:DerivePath
            (Join-Path -Path $script:ModuleRoot -ChildPath 'Private/Identity/Get-NormalizedProvisioningTenantDomain.ps1')
            (Join-Path -Path $script:ModuleRoot -ChildPath 'Private/Identity/Get-CanonicalProvisioningUpnCandidate.ps1')
            (Join-Path -Path $script:ModuleRoot -ChildPath 'Private/Identity/Get-ProvisioningCsvUpnParts.ps1')
            (Join-Path -Path $script:ModuleRoot -ChildPath 'Private/Identity/Get-ProvisioningUpnBaseLocalPart.ps1')
            (Join-Path -Path $script:ModuleRoot -ChildPath 'Private/Identity/Test-MappedProvisioningIdentityBoundary.ps1')
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
            $text = Get-Content -LiteralPath $path -Raw
            foreach ($pattern in $dangerousPatterns) {
                $text | Should -Not -Match $pattern
            }
        }
    }

    It 'throws ArgumentException for null row without emitting output' {
        $result = Invoke-DeriveExpectFailure -Row $null -Mapped (New-TestMapped)
        $result.Thrown.Exception | Should -BeOfType ([System.ArgumentException])
        $result.Emitted | Should -BeNullOrEmpty
    }

    It 'does not echo hostile CSV UserPrincipalName content in domain mismatch errors' {
        $hostileMarker = 'EVILDOMAINMARKER'
        $row = New-TestRow -Properties @{
            FirstName         = 'Ada'
            LastName          = 'Lovelace'
            UserPrincipalName = "ada@$hostileMarker.contoso.evil"
            SourceLineNumber  = 11
        }

        $result = Invoke-DeriveExpectFailure -Row $row -Mapped (New-TestMapped)
        $result.Thrown.Exception.Message | Should -Match 'physical line 11'
        $result.Thrown.Exception.Message | Should -Not -Match $hostileMarker
    }

    It 'does not echo hostile content in invalid UserPrincipalName shape errors' {
        $hostile = 'not-valid<' + ('x' * 80) + '>'
        $row = New-TestRow -Properties @{
            FirstName         = 'Ada'
            LastName          = 'Lovelace'
            UserPrincipalName = $hostile
            SourceLineNumber  = 12
        }

        $result = Invoke-DeriveExpectFailure -Row $row -Mapped (New-TestMapped)
        $result.Thrown.Exception.Message | Should -Match 'physical line 12'
        $result.Thrown.Exception.Message | Should -Not -Match 'not-valid'
        $result.Thrown.Exception.Message | Should -Not -Match '<'
    }

    It 'throws when CSV UserPrincipalName exceeds maximum bounded length on the row' {
        $longUpn = ('a' * 102) + '@contoso.com'
        $row = New-TestRow -Properties @{
            FirstName         = 'Ada'
            LastName          = 'Lovelace'
            UserPrincipalName = $longUpn
        }

        $result = Invoke-DeriveExpectFailure -Row $row -Mapped (New-TestMapped)
        $result.Thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $result.Emitted | Should -BeNullOrEmpty
    }

    It 'throws when TenantDomainSuffix exceeds maximum bounded length' {
        $row = New-TestRow -Properties @{ FirstName = 'Ada'; LastName = 'Lovelace' }
        $suffix = 'a' * ($script:MaxDomainSuffixLength + 1)

        $result = Invoke-DeriveExpectFailure -Row $row -Mapped (New-TestMapped) -TenantDomainSuffix $suffix
        $result.Thrown.Exception | Should -BeOfType ([System.ArgumentException])
        $result.Emitted | Should -BeNullOrEmpty
    }

    It 'caps MaximumUpnCandidates at 99 to limit exists-check work per row' {
        { Get-DerivedUserPrincipalName -ProvisioningRow (New-TestRow -Properties @{ FirstName = 'A'; LastName = 'B' }) -MappedProvisioningIdentity (New-TestMapped) -TenantDomainSuffix 'contoso.com' -MaximumUpnCandidates 100 -UpnExists { $false } } |
            Should -Throw
    }

    It 'returns UserPrincipalName within Entra-aligned maximum length on success' {
        $row = New-TestRow -Properties @{ FirstName = 'Ada'; LastName = 'Lovelace' }
        $derived = Get-DerivedUserPrincipalName `
            -ProvisioningRow $row `
            -MappedProvisioningIdentity (New-TestMapped) `
            -TenantDomainSuffix 'contoso.com' `
            -UpnExists { $false }

        $derived.UserPrincipalName.Length | Should -BeLessOrEqual $script:MaxUpnLength
        $derived.UserPrincipalName | Should -Match '^[a-z0-9@.-]+$'
    }

    It 'invokes UpnExists at most MaximumUpnCandidates times per row' {
        $row = New-TestRow -Properties @{ FirstName = 'Ada'; LastName = 'Lovelace' }
        $script:probeCount = 0

        { Get-DerivedUserPrincipalName `
            -ProvisioningRow $row `
            -MappedProvisioningIdentity (New-TestMapped) `
            -TenantDomainSuffix 'contoso.com' `
            -MaximumUpnCandidates 5 `
            -UpnExists {
                $script:probeCount++
                $true
            } } | Should -Throw

        $script:probeCount | Should -Be 5
    }
}
