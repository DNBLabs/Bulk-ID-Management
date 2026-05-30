<#
.SYNOPSIS
    Pester tests for Implementation Plan Task 1 Sub-task C (BulkIdentityManagement module manifest).

.DESCRIPTION
    Validates manifest presence, metadata contract (PowerShell 7.2+, Core edition, CONTEXT narrative),
    exact rollup Microsoft.Graph pin aligned with docs/tasks/MicrosoftGraph.psgallery.version.txt,
    explicit non-wildcard export lists, a stable GUID, and absence of a root requirements.psd1 second authority.
    Security-oriented checks cover empty optional load surfaces (ScriptsToProcess, NestedModules,
    RequiredAssemblies) and reject high-signal secret material patterns in tracked manifest text.
    Test-ModuleManifest with RequiredModules resolution is enforced in CI by .github/scripts/Invoke-ModuleManifestCI.ps1.
#>

BeforeAll {
    $repoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:RepoRoot = $repoRoot
    $script:Psd1Path = Join-Path -Path $repoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psd1'
    $script:PinPath = Join-Path -Path $repoRoot -ChildPath 'docs/tasks/MicrosoftGraph.psgallery.version.txt'
    $script:ExpectedPin = (Get-Content -LiteralPath $script:PinPath -Raw).Trim()
    if ($script:ExpectedPin -notmatch '^\d+\.\d+\.\d+$') {
        throw 'Unexpected pin file format at docs/tasks/MicrosoftGraph.psgallery.version.txt'
    }
}

Describe 'Task 1 Sub-task C - BulkIdentityManagement module manifest' {

    It 'places BulkIdentityManagement.psd1 under src/Modules/BulkIdentityManagement' {
        Test-Path -LiteralPath $Psd1Path | Should -BeTrue
        $resolved = Resolve-Path -LiteralPath $Psd1Path
        $rootPrefix = $script:RepoRoot.TrimEnd('/', '\') + [System.IO.Path]::DirectorySeparatorChar
        (
            $resolved.Path.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
            $resolved.Path.Equals($script:RepoRoot.TrimEnd('/', '\'), [System.StringComparison]::OrdinalIgnoreCase)
        ) | Should -BeTrue
    }

    It 'loads manifest data with Import-PowerShellDataFile' {
        { Import-PowerShellDataFile -Path $Psd1Path } | Should -Not -Throw
    }

    It 'declares RootModule BulkIdentityManagement.psm1' {
        $data = Import-PowerShellDataFile -Path $Psd1Path
        $data.RootModule | Should -Be 'BulkIdentityManagement.psm1'
    }

    It 'declares PowerShellVersion 7.2 and Core-compatible editions only' {
        $data = Import-PowerShellDataFile -Path $Psd1Path
        $data.PowerShellVersion | Should -Be '7.2'
        @($data.CompatiblePSEditions) | Should -Contain 'Core'
        @($data.CompatiblePSEditions) | Should -Not -Contain 'Desktop'
    }

    It 'uses semantic version 0.1.0 for the pre-1.0 scaffold' {
        $data = Import-PowerShellDataFile -Path $Psd1Path
        $data.ModuleVersion | Should -Be '0.1.0'
    }

    It 'documents PowerShell 7.2+, 7.4+ preferred, and CONTEXT.md in the description' {
        $data = Import-PowerShellDataFile -Path $Psd1Path
        $data.Description | Should -Match '7\.2'
        $data.Description | Should -Match '7\.4'
        $data.Description | Should -Match 'CONTEXT\.md'
    }

    It 'declares a stable GUID value' {
        $data = Import-PowerShellDataFile -Path $Psd1Path
        { [guid]::Parse($data.GUID) } | Should -Not -Throw
    }

    It 'exports public functions and keeps cmdlets, aliases, and variables empty' {
        $data = Import-PowerShellDataFile -Path $Psd1Path
        @($data.FunctionsToExport) | Should -BeExactly @(
            'Import-ProvisioningCsv'
            'Get-MappedProvisioningIdentity'
            'Get-DerivedUserPrincipalName'
            'Connect-ProvisioningGraph'
            'Invoke-BulkIdentityProvisioning'
        )
        $data.CmdletsToExport.Count | Should -Be 0
        $data.AliasesToExport.Count | Should -Be 0
        $data.VariablesToExport.Count | Should -Be 0
    }

    It 'pins Microsoft.Graph only to the exact version recorded in the pin file (non-drifting range)' {
        $data = Import-PowerShellDataFile -Path $Psd1Path
        $data.RequiredModules.Count | Should -Be 1
        $req = $data.RequiredModules[0]
        $req.ModuleName | Should -Be 'Microsoft.Graph'
        $req.ModuleVersion | Should -Be $script:ExpectedPin
        $req.MaximumVersion | Should -Be $script:ExpectedPin
    }

    It 'does not introduce requirements.psd1 at the repository root' {
        $rootRequirements = Join-Path -Path $script:RepoRoot -ChildPath 'requirements.psd1'
        Test-Path -LiteralPath $rootRequirements | Should -BeFalse
    }

    It 'does not declare ScriptsToProcess, NestedModules, or RequiredAssemblies (reduces import-time execution and assembly load surface)' {
        $data = Import-PowerShellDataFile -Path $Psd1Path
        foreach ($key in @('ScriptsToProcess', 'NestedModules', 'RequiredAssemblies')) {
            if ($data.ContainsKey($key)) {
                @($data[$key]).Count | Should -Be 0 -Because "Manifest key '$key' must be empty when present"
            }
        }
    }

    It 'does not embed high-signal secret or private-key markers in manifest text' {
        $raw = Get-Content -LiteralPath $Psd1Path -Raw
        $dangerousPatterns = @(
            '(?i)client[_-]?secret'
            '(?i)(?:api|access)[_-]?token\s*[:=]\s*[^\s''"]+'
            '-----BEGIN [A-Z ]*PRIVATE KEY-----'
            '(?i)-----BEGIN OPENSSH PRIVATE KEY-----'
        )
        foreach ($pattern in $dangerousPatterns) {
            $raw | Should -Not -Match $pattern
        }
    }

    It 'does not use wildcard exports for functions, cmdlets, aliases, or variables' {
        $data = Import-PowerShellDataFile -Path $Psd1Path
        foreach ($key in @('FunctionsToExport', 'CmdletsToExport', 'AliasesToExport', 'VariablesToExport')) {
            if ($data.ContainsKey($key)) {
                foreach ($entry in @($data[$key])) {
                    [string] $entry | Should -Not -Match '\*' -Because "Wildcard exports in '$key' widen accidental public surface"
                }
            }
        }
    }
}
