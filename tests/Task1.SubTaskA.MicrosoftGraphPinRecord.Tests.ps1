<#
.SYNOPSIS
    Pester tests for Implementation Plan Task 1 Sub-task A (PSGallery Microsoft.Graph pin record).

.DESCRIPTION
    Sub-task A requires a committed, exact version string for the rollup Microsoft.Graph module as
    reported by PSGallery at implementation time. These tests enforce that the record file exists,
    is well-formed, and (when enabled) still matches the gallery for local validation.

.NOTES
    Live gallery comparison runs only when environment variable VALIDATE_PSGRAPH_LIVE is set to 1
    so default CI or offline runs are not blocked by network or upstream version bumps.

    Security: The pin file must contain only a public version label (no secrets, no script). Tests
    use -LiteralPath, strict line parsing (no raw slurp of attacker-controlled multi-line payloads),
    and a bounded version pattern before any string comparison. Find-Module targets the official
    PSGallery repository name only; machine trust (registered gallery URIs) remains an operator
    responsibility.
#>

BeforeAll {
    $repoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $expectedRelative = [System.IO.Path]::Combine('docs', 'tasks', 'MicrosoftGraph.psgallery.version.txt')
    $script:PinRecordPath = Join-Path -Path $repoRoot -ChildPath $expectedRelative
    $script:RepoRootCanonical = $repoRoot
}

Describe 'Task 1 Sub-task A - Microsoft.Graph PSGallery pin record' {

    It 'commits a pin record file under docs/tasks' {
        Test-Path -LiteralPath $PinRecordPath | Should -BeTrue
        $resolved = Resolve-Path -LiteralPath $PinRecordPath
        $resolved.Path.StartsWith(
            $RepoRootCanonical,
            [System.StringComparison]::OrdinalIgnoreCase) | Should -BeTrue
    }

    It 'pin record is exactly one non-empty line matching a strict numeric version token' {
        $lines = @(Get-Content -LiteralPath $PinRecordPath -ErrorAction Stop)
        $nonBlank = @($lines | Where-Object { $null -ne $_ -and $_.Trim() -ne '' })
        $nonBlank.Count | Should -BeExactly 1
        $line = $nonBlank[0].Trim()
        $line | Should -Match '^\d+\.\d+\.\d+$'
        $parsed = $null
        [System.Version]::TryParse($line, [ref]$parsed) | Should -BeTrue
        $null -ne $parsed | Should -BeTrue
    }

    It 'pin record matches live PSGallery Microsoft.Graph when VALIDATE_PSGRAPH_LIVE=1' -Skip:($env:VALIDATE_PSGRAPH_LIVE -ne '1') {
        $lines = @(Get-Content -LiteralPath $PinRecordPath -ErrorAction Stop)
        $recorded = ($lines | Where-Object { $null -ne $_ -and $_.Trim() -ne '' } | Select-Object -First 1).Trim()
        $recorded | Should -Match '^\d+\.\d+\.\d+$'

        $galleryModule = Find-Module -Name 'Microsoft.Graph' -Repository 'PSGallery' -ErrorAction Stop |
            Select-Object -First 1
        $galleryModule | Should -Not -BeNullOrEmpty
        $galleryModule.Name | Should -BeExactly 'Microsoft.Graph'

        $live = $galleryModule.Version.ToString()
        $live | Should -Match '^\d+\.\d+\.\d+$'
        $recorded | Should -BeExactly $live
    }
}
