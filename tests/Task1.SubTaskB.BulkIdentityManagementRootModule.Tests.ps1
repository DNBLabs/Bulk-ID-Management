<#
.SYNOPSIS
    Pester tests for Implementation Plan Task 1 Sub-task B (BulkIdentityManagement root script module).

.DESCRIPTION
    Validates the repository root script module path, normative documentation pointer, empty public
    surface on import, and absence of Microsoft Graph client calls in module source (CI scope).
#>

BeforeAll {
    $repoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $repoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    $script:Psd1Path = Join-Path -Path $repoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psd1'
}

Describe 'Task 1 Sub-task B - BulkIdentityManagement root script module' {

    It 'places BulkIdentityManagement.psm1 beside the module manifest when manifest exists' {
        Test-Path -LiteralPath $Psm1Path | Should -BeTrue
        if (Test-Path -LiteralPath $Psd1Path) {
            (Split-Path -Parent -Path $Psm1Path) | Should -Be (Split-Path -Parent -Path $Psd1Path)
        }
    }

    It 'documents CONTEXT.md as the normative contract in the module comment help' {
        $text = Get-Content -LiteralPath $Psm1Path -Raw
        $text | Should -Match 'CONTEXT\.md'
    }

    It 'imports the root script module without exporting public commands' {
        $moduleInfo = Import-Module -Name $Psm1Path -PassThru -Force
        try {
            $moduleInfo.ExportedFunctions.Count | Should -Be 0
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
}
