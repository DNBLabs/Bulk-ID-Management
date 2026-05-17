<#
.SYNOPSIS
    Security regression tests for Task 3 Sub-task A (module layout and dot-source wiring).

.DESCRIPTION
    Validates dot-source containment, literal path usage, absence of high-risk execution patterns,
    and that canonical header constants are not exported from the module public surface.
#>

BeforeAll {
    $repoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ModuleRoot = Join-Path -Path $repoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    $script:Psm1Path = Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psm1'
    $script:PrivateDir = Join-Path -Path $script:ModuleRoot -ChildPath 'Private'
    $script:PublicDir = Join-Path -Path $script:ModuleRoot -ChildPath 'Public'
}

Describe 'Task 3 Sub-task A - security regressions' {

    It 'resolves and confines dot-sourced scripts under the module root directory before loading' {
        $text = Get-Content -LiteralPath $Psm1Path -Raw
        $text | Should -Match 'Resolve-Path\s+-LiteralPath\s+\$_.FullName'
        $text | Should -Match '\$moduleRootPrefix\s*=\s*\$moduleRootResolved\s*\+\s*\[System\.IO\.Path\]::DirectorySeparatorChar'
        $text | Should -Match 'StartsWith\s*\(\s*\$moduleRootPrefix'
    }

    It 'rejects a sibling directory whose path shares the module root as a string prefix only' {
        $moduleRoot = Join-Path -Path $TestDrive -ChildPath 'BulkIdentityManagement'
        $siblingRoot = "${moduleRoot}Evil"
        $moduleRootPrefix = $moduleRoot + [System.IO.Path]::DirectorySeparatorChar
        $outsideScript = Join-Path -Path $siblingRoot -ChildPath 'Outside.ps1'
        New-Item -ItemType Directory -Path $siblingRoot -Force | Out-Null
        Set-Content -LiteralPath $outsideScript -Value '# outside' -Encoding utf8NoBOM
        $resolvedOutside = (Resolve-Path -LiteralPath $outsideScript).ProviderPath
        $resolvedOutside.StartsWith($moduleRoot, [System.StringComparison]::OrdinalIgnoreCase) | Should -BeTrue
        $resolvedOutside.StartsWith($moduleRootPrefix, [System.StringComparison]::OrdinalIgnoreCase) | Should -BeFalse
    }

    It 'enumerates module scripts with LiteralPath and a ps1-only filter' {
        $text = Get-Content -LiteralPath $Psm1Path -Raw
        $text | Should -Match 'Get-ChildItem\s+-LiteralPath\s+\$scriptDirectory\s+-Filter\s+''\*\.ps1'''
    }

    It 'does not dot-source from user-controlled or dynamic path expressions' {
        $text = Get-Content -LiteralPath $Psm1Path -Raw
        $text | Should -Not -Match '(?i)Invoke-Expression'
        $text | Should -Not -Match '(?i)\biex\b'
        $text | Should -Not -Match '(?i)Invoke-Command\s+.*-ScriptBlock'
        $text | Should -Not -Match '\. \$env:'
        $text | Should -Not -Match '\. \$args'
    }

    It 'does not use high-risk network or process cmdlets in module layout scripts' {
        $paths = @($Psm1Path)
        $paths += @(Get-ChildItem -LiteralPath $PrivateDir -Filter '*.ps1' -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
        $paths += @(Get-ChildItem -LiteralPath $PublicDir -Filter '*.ps1' -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
        $dangerousPatterns = @(
            '(?i)\bInvoke-WebRequest\b'
            '(?i)\bInvoke-RestMethod\b'
            '(?i)\bStart-Process\b'
        )
        foreach ($path in $paths) {
            $text = Get-Content -LiteralPath $path -Raw
            foreach ($pattern in $dangerousPatterns) {
                $text | Should -Not -Match $pattern
            }
        }
    }

    It 'does not export canonical header name variables on the module public surface' {
        $resolvedPsm1 = Resolve-Path -LiteralPath $Psm1Path
        $moduleInfo = Import-Module -Name $resolvedPsm1.Path -PassThru -Force
        try {
            { Get-Command -Module $moduleInfo -Name RequiredProvisioningCsvHeaderNames -ErrorAction Stop } |
                Should -Throw
            { Get-Command -Module $moduleInfo -Name OptionalProvisioningCsvHeaderNames -ErrorAction Stop } |
                Should -Throw
            $moduleInfo.ExportedVariables.Count | Should -Be 0
        }
        finally {
            Remove-Module -ModuleInfo $moduleInfo -Force -ErrorAction SilentlyContinue
        }
    }
}
