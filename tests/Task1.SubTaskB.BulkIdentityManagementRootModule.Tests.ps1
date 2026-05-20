<#
.SYNOPSIS
    Pester tests for Implementation Plan Task 1 Sub-task B (BulkIdentityManagement root script module).

.DESCRIPTION
    Validates the repository root script module path, normative documentation pointer, empty public
    surface on import, repository containment of the resolved path, absence of Microsoft Graph client
    calls, and absence of high-risk execution or network surface patterns in module source (CI scope).
#>

BeforeAll {
    $repoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:RepoRoot = $repoRoot
    $script:Psm1Path = Join-Path -Path $repoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    $script:Psd1Path = Join-Path -Path $repoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psd1'
}

Describe 'Task 1 Sub-task B - BulkIdentityManagement root script module' {

    It 'places BulkIdentityManagement.psm1 beside the module manifest when manifest exists' {
        Test-Path -LiteralPath $Psm1Path | Should -BeTrue
        $resolvedPsm1 = Resolve-Path -LiteralPath $Psm1Path
        $rootPrefix = $script:RepoRoot.TrimEnd('/', '\') + [System.IO.Path]::DirectorySeparatorChar
        (
            $resolvedPsm1.Path.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
            $resolvedPsm1.Path.Equals($script:RepoRoot.TrimEnd('/', '\'), [System.StringComparison]::OrdinalIgnoreCase)
        ) | Should -BeTrue
        if (Test-Path -LiteralPath $Psd1Path) {
            (Split-Path -Parent -Path $Psm1Path) | Should -Be (Split-Path -Parent -Path $Psd1Path)
        }
    }

    It 'documents CONTEXT.md as the normative contract in the module comment help' {
        $text = Get-Content -LiteralPath $Psm1Path -Raw
        $text | Should -Match 'CONTEXT\.md'
    }

    It 'imports the root script module with Task 3, Task 4, and Task 5 public functions exported' {
        $resolvedPsm1 = Resolve-Path -LiteralPath $Psm1Path
        $moduleInfo = Import-Module -Name $resolvedPsm1.Path -PassThru -Force
        try {
            @($moduleInfo.ExportedFunctions.Keys | Sort-Object) | Should -BeExactly @(
                'Get-DerivedUserPrincipalName'
                'Get-MappedProvisioningIdentity'
                'Import-ProvisioningCsv'
            )
            $moduleInfo.ExportedCmdlets.Count | Should -Be 0
            $moduleInfo.ExportedAliases.Count | Should -Be 0
        }
        finally {
            Remove-Module -ModuleInfo $moduleInfo -Force -ErrorAction SilentlyContinue
        }
    }

    It 'does not reference Connect-MgGraph or Import-Module Microsoft.Graph in module source' {
        $text = Get-Content -LiteralPath $Psm1Path -Raw
        $text | Should -Not -Match '(?i)Connect-MgGraph'
        $text | Should -Not -Match '(?i)Import-Module\s+Microsoft\.Graph'
    }

    It 'does not use Invoke-Expression, iex, or interactive web or process cmdlets in module source' {
        $text = Get-Content -LiteralPath $Psm1Path -Raw
        $dangerousPatterns = @(
            '(?i)\bInvoke-Expression\b'
            '(?i)\biex\b'
            '(?i)\bInvoke-WebRequest\b'
            '(?i)\bInvoke-RestMethod\b'
            '(?i)\bStart-Process\b'
        )
        foreach ($pattern in $dangerousPatterns) {
            $text | Should -Not -Match $pattern
        }
    }
}
