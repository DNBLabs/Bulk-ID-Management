<#
.SYNOPSIS
    Security regression tests for Task 3 Sub-task G (module export wiring).

.DESCRIPTION
    Confirms the root script module does not add Graph client calls at import time,
    keeps the public export surface limited to documented public functions, and does not
    widen cmdlet, alias, or variable exports.
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
        'Invoke-BulkIdentityProvisioning'
    )
}

Describe 'Task 3 Sub-task G - export wiring security' {

    It 'does not reference Connect-MgGraph or Import-Module Microsoft.Graph in the root script module' {
        $text = Get-Content -LiteralPath $script:Psm1Path -Raw
        $text | Should -Not -Match '(?i)Connect-MgGraph'
        $text | Should -Not -Match '(?i)Import-Module\s+Microsoft\.Graph'
    }

    It 'does not use high-risk execution or network cmdlets in the root script module' {
        $text = Get-Content -LiteralPath $script:Psm1Path -Raw
        $dangerousPatterns = @(
            '(?i)\bInvoke-Expression\b'
            '(?i)\biex\b'
            '(?i)\bInvoke-Command\b'
            '(?i)\bInvoke-WebRequest\b'
            '(?i)\bInvoke-RestMethod\b'
            '(?i)\bStart-Process\b'
        )
        foreach ($pattern in $dangerousPatterns) {
            $text | Should -Not -Match $pattern
        }
    }

    It 'does not use wildcard Export-ModuleMember patterns' {
        $text = Get-Content -LiteralPath $script:Psm1Path -Raw
        $text | Should -Not -Match 'Export-ModuleMember\s+-Function\s+\*'
        $text | Should -Not -Match "Export-ModuleMember\s+-Function\s+@\('\*'\)"
        $text | Should -Not -Match 'Export-ModuleMember\s+-Cmdlet\s+\*'
        $text | Should -Not -Match 'Export-ModuleMember\s+-Variable\s+\*'
        $text | Should -Not -Match 'Export-ModuleMember\s+-Alias\s+\*'
    }

    It 'exports only documented public functions via Export-ModuleMember without cmdlet or variable exports' {
        $text = Get-Content -LiteralPath $script:Psm1Path -Raw
        $text | Should -Match 'Export-ModuleMember\s+-Function\s+@\('
        foreach ($functionName in $script:ExpectedPublicFunctions) {
            $escapedFunctionName = [regex]::Escape($functionName)
            $text | Should -Match $escapedFunctionName
        }
        $text | Should -Not -Match 'Export-ModuleMember\s+-Cmdlet'
        $text | Should -Not -Match 'Export-ModuleMember\s+-Variable'
        $text | Should -Not -Match 'Export-ModuleMember\s+-Alias'
    }

    It 'does not declare wildcard function exports in the manifest' {
        $data = Import-PowerShellDataFile -Path $script:Psd1Path
        foreach ($key in @('FunctionsToExport', 'CmdletsToExport', 'AliasesToExport', 'VariablesToExport')) {
            if ($data.ContainsKey($key)) {
                foreach ($entry in @($data[$key])) {
                    [string] $entry | Should -Not -Match '\*' -Because "Wildcard exports in '$key' widen accidental public surface"
                }
            }
        }
    }

    It 'lists documented public function exports and keeps other manifest export lists empty' {
        $data = Import-PowerShellDataFile -Path $script:Psd1Path
        @($data.FunctionsToExport) | Should -BeExactly @($script:ExpectedPublicFunctions)
        $data.CmdletsToExport.Count | Should -Be 0
        $data.AliasesToExport.Count | Should -Be 0
        $data.VariablesToExport.Count | Should -Be 0
    }

    It 'does not declare ScriptsToProcess, NestedModules, or RequiredAssemblies in the manifest' {
        $data = Import-PowerShellDataFile -Path $script:Psd1Path
        foreach ($key in @('ScriptsToProcess', 'NestedModules', 'RequiredAssemblies')) {
            if ($data.ContainsKey($key)) {
                @($data[$key]).Count | Should -Be 0 -Because "Manifest key '$key' must be empty when present"
            }
        }
    }

    It 'does not embed high-signal secret or private-key markers in manifest text' {
        $raw = Get-Content -LiteralPath $script:Psd1Path -Raw
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

    It 'does not export private CSV helpers or header constants on the module public surface after import' {
        $resolvedPsm1 = Resolve-Path -LiteralPath $script:Psm1Path
        $moduleInfo = Import-Module -Name $resolvedPsm1.Path -PassThru -Force
        try {
            @($moduleInfo.ExportedFunctions.Keys | Sort-Object) | Should -BeExactly @(
                'Connect-ProvisioningGraph'
                'Get-DerivedUserPrincipalName'
                'Get-MappedProvisioningIdentity'
                'Import-ProvisioningCsv'
                'Invoke-BulkIdentityProvisioning'
            )
            $moduleInfo.ExportedCmdlets.Count | Should -Be 0
            $moduleInfo.ExportedAliases.Count | Should -Be 0
            $moduleInfo.ExportedVariables.Count | Should -Be 0

            { Get-Command -Module $moduleInfo -Name Read-ProvisioningCsvUtf8 -ErrorAction Stop } |
                Should -Throw
            { Get-Command -Module $moduleInfo -Name Get-ProvisioningCsvMaterializedRows -ErrorAction Stop } |
                Should -Throw
            { Get-Command -Module $moduleInfo -Name RequiredProvisioningCsvHeaderNames -ErrorAction Stop } |
                Should -Throw
        }
        finally {
            Remove-Module -ModuleInfo $moduleInfo -Force -ErrorAction SilentlyContinue
        }
    }
}
