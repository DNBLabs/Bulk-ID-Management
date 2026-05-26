<#
.SYNOPSIS
    Pester tests for Implementation Plan Task 3 Sub-task G (module export wiring).

.DESCRIPTION
    Validates manifest FunctionsToExport, Export-ModuleMember alignment, and that
    public functions after Import-Module (Task 3 CSV import; Task 4 name mapping).
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ModuleRoot = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    $script:Psm1Path = Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psm1'
    $script:Psd1Path = Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psd1'
    $script:ExpectedPublicFunctions = @(
        'Import-ProvisioningCsv'
        'Get-MappedProvisioningIdentity'
        'Get-DerivedUserPrincipalName'
        'Connect-ProvisioningGraph'
    )
}

Describe 'Task 3 Sub-task G - BulkIdentityManagement export wiring' {

    It 'lists Task 3, Task 4, and Task 5 public functions in FunctionsToExport' {
        $data = Import-PowerShellDataFile -Path $script:Psd1Path
        @($data.FunctionsToExport) | Should -BeExactly @($script:ExpectedPublicFunctions)
        $data.CmdletsToExport.Count | Should -Be 0
        $data.AliasesToExport.Count | Should -Be 0
        $data.VariablesToExport.Count | Should -Be 0
    }

    It 'exports public functions via Export-ModuleMember in the root script module' {
        $text = Get-Content -LiteralPath $script:Psm1Path -Raw
        $text | Should -Match 'Export-ModuleMember\s+-Function\s+@\('
        foreach ($functionName in $script:ExpectedPublicFunctions) {
            $escapedFunctionName = [regex]::Escape($functionName)
            $text | Should -Match $escapedFunctionName
        }
    }

    It 'exposes Task 3, Task 4, and Task 5 public functions when importing the root script module' {
        $resolvedPsm1 = Resolve-Path -LiteralPath $script:Psm1Path
        $moduleInfo = Import-Module -Name $resolvedPsm1.Path -PassThru -Force
        try {
            @($moduleInfo.ExportedFunctions.Keys | Sort-Object) | Should -BeExactly @(
                'Connect-ProvisioningGraph'
                'Get-DerivedUserPrincipalName'
                'Get-MappedProvisioningIdentity'
                'Import-ProvisioningCsv'
            )
            $moduleInfo.ExportedCmdlets.Count | Should -Be 0
            $moduleInfo.ExportedAliases.Count | Should -Be 0
            foreach ($functionName in $script:ExpectedPublicFunctions) {
                Get-Command -Module $moduleInfo -Name $functionName -CommandType Function |
                    Should -Not -BeNullOrEmpty
            }
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
            { Get-Command -Module $moduleInfo -Name Get-NormalizedProvisioningMailNickname -ErrorAction Stop } |
                Should -Throw
            { Get-Command -Module $moduleInfo -Name Get-ProvisioningNameMappingFromRow -ErrorAction Stop } |
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
        @($manifestInfo.ExportedFunctions.Keys | Sort-Object) | Should -BeExactly @(
            'Connect-ProvisioningGraph'
            'Get-DerivedUserPrincipalName'
            'Get-MappedProvisioningIdentity'
            'Import-ProvisioningCsv'
        )
    }
}
