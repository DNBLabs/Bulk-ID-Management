<#
.SYNOPSIS
    Pester tests for Implementation Plan Task 3 Sub-task G (module export wiring).

.DESCRIPTION
    Validates manifest FunctionsToExport, Export-ModuleMember alignment, and that
    Import-ProvisioningCsv is the sole public function after Import-Module.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ModuleRoot = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    $script:Psm1Path = Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psm1'
    $script:Psd1Path = Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psd1'
    $script:ExpectedPublicFunction = 'Import-ProvisioningCsv'
}

Describe 'Task 3 Sub-task G - BulkIdentityManagement export wiring' {

    It 'lists Import-ProvisioningCsv as the only function in FunctionsToExport' {
        $data = Import-PowerShellDataFile -Path $script:Psd1Path
        @($data.FunctionsToExport) | Should -BeExactly @($script:ExpectedPublicFunction)
        $data.CmdletsToExport.Count | Should -Be 0
        $data.AliasesToExport.Count | Should -Be 0
        $data.VariablesToExport.Count | Should -Be 0
    }

    It 'exports Import-ProvisioningCsv via Export-ModuleMember in the root script module' {
        $text = Get-Content -LiteralPath $script:Psm1Path -Raw
        $text | Should -Match "Export-ModuleMember\s+-Function\s+@\(\s*'$script:ExpectedPublicFunction'\s*\)"
    }

    It 'exposes Import-ProvisioningCsv as the only exported function when importing the root script module' {
        $resolvedPsm1 = Resolve-Path -LiteralPath $script:Psm1Path
        $moduleInfo = Import-Module -Name $resolvedPsm1.Path -PassThru -Force
        try {
            @($moduleInfo.ExportedFunctions.Keys) | Should -BeExactly @($script:ExpectedPublicFunction)
            $moduleInfo.ExportedCmdlets.Count | Should -Be 0
            $moduleInfo.ExportedAliases.Count | Should -Be 0
            Get-Command -Module $moduleInfo -Name $script:ExpectedPublicFunction -CommandType Function |
                Should -Not -BeNullOrEmpty
        }
        finally {
            Remove-Module -ModuleInfo $moduleInfo -Force -ErrorAction SilentlyContinue
        }
    }

    It 'does not export private CSV helper functions on the module public surface' {
        $resolvedPsm1 = Resolve-Path -LiteralPath $script:Psm1Path
        $moduleInfo = Import-Module -Name $resolvedPsm1.Path -PassThru -Force
        try {
            { Get-Command -Module $moduleInfo -Name Get-ProvisioningCsvLogicalRecords -ErrorAction Stop } |
                Should -Throw
            { Get-Command -Module $moduleInfo -Name Read-ProvisioningCsvUtf8 -ErrorAction Stop } |
                Should -Throw
        }
        finally {
            Remove-Module -ModuleInfo $moduleInfo -Force -ErrorAction SilentlyContinue
        }
    }

    It 'reports Import-ProvisioningCsv from Test-ModuleManifest when the pinned Microsoft.Graph module is available' {
        $pinPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/tasks/MicrosoftGraph.psgallery.version.txt'
        $pinVersion = (Get-Content -LiteralPath $pinPath -Raw).Trim()
        $graphAvailable = Get-Module -ListAvailable -Name Microsoft.Graph |
            Where-Object { $_.Version.ToString() -eq $pinVersion } |
            Select-Object -First 1

        if (-not $graphAvailable) {
            Set-ItResult -Skipped -Because "Microsoft.Graph $pinVersion is not installed locally"
            return
        }

        $manifestInfo = Test-ModuleManifest -Path $script:Psd1Path -ErrorAction Stop
        @($manifestInfo.ExportedFunctions.Keys) | Should -BeExactly @($script:ExpectedPublicFunction)
    }
}
