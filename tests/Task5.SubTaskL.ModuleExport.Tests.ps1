<#
.SYNOPSIS
    Pester tests for Task 5 module export and Import-Map-Derive pipeline.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    $script:Psd1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psd1'
    $script:ModuleRoot = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 5 - module export' {

    It 'exports Get-DerivedUserPrincipalName from BulkIdentityManagement.psm1' {
        (Get-Command -Module BulkIdentityManagement -Name 'Get-DerivedUserPrincipalName' -ErrorAction Stop) |
            Should -Not -BeNullOrEmpty
    }

    It 'lists Get-DerivedUserPrincipalName in FunctionsToExport' {
        $manifest = Test-ModuleManifest -Path $script:Psd1Path -ErrorAction Stop
        $manifest.ExportedFunctions.Keys | Should -Contain 'Get-DerivedUserPrincipalName'
    }

    It 'does not reference Microsoft Graph in Task 5 module scripts' {
        $task5Patterns = @(
            'Get-DerivedUserPrincipalName'
            'Get-NormalizedProvisioningTenantDomain'
            'Get-CanonicalProvisioningUpnCandidate'
            'Get-ProvisioningCsvUpnParts'
            'Get-ProvisioningUpnBaseLocalPart'
            'Test-MappedProvisioningIdentityBoundary'
        )
        $hits = @()
        Get-ChildItem -LiteralPath $script:ModuleRoot -Recurse -Filter '*.ps1' -File |
            ForEach-Object {
                $content = Get-Content -LiteralPath $_.FullName -Raw
                foreach ($pattern in $task5Patterns) {
                    if ($content -match [regex]::Escape($pattern)) {
                        if ($content -match 'Microsoft\.Graph|Connect-MgGraph') {
                            $hits += $_.FullName
                        }
                    }
                }
            }
        $hits | Should -BeNullOrEmpty
    }
}

Describe 'Task 5 - Import Map Derive integration' {

    It 'derives UPN from CSV row through map then derive' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'derive-smoke.csv'
        @(
            'FirstName,LastName,Department'
            'Ada,Lovelace,Engineering'
        ) | Set-Content -LiteralPath $csvPath -Encoding utf8NoBOM

        $row = Import-ProvisioningCsv -Path $csvPath | Select-Object -First 1
        $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row
        $derived = Get-DerivedUserPrincipalName `
            -ProvisioningRow $row `
            -MappedProvisioningIdentity $mapped `
            -TenantDomainSuffix 'contoso.com' `
            -UpnExists { $false }

        $derived.UserPrincipalName | Should -Be 'ada.lovelace@contoso.com'
        $derived.AttemptCount | Should -Be 1
    }
}
