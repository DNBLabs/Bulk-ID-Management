<#
.SYNOPSIS
    Pester tests for Task 14 default validate-only GitHub Actions CI contract.

.DESCRIPTION
    Asserts repository CI scripts and workflow wiring match CONTEXT: pwsh gates for
    PSScriptAnalyzer (Error+Warning), Pester, and optional manifest validation without
    tenant-mutating entry points on the default pipeline.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:CiWorkflowPath = Join-Path -Path $script:RepoRoot -ChildPath '.github/workflows/ci.yml'
    $script:AnalyzerScriptPath = Join-Path -Path $script:RepoRoot -ChildPath '.github/scripts/Invoke-PSScriptAnalyzerCI.ps1'
    $script:ManifestScriptPath = Join-Path -Path $script:RepoRoot -ChildPath '.github/scripts/Invoke-ModuleManifestCI.ps1'
}

Describe 'Task 14 - default validate-only CI' {

    It 'exposes the default CI workflow for push and pull_request on main' {
        Test-Path -LiteralPath $script:CiWorkflowPath -PathType Leaf | Should -BeTrue
        $workflow = Get-Content -LiteralPath $script:CiWorkflowPath -Raw
        $workflow | Should -Match '(?m)^on:\s*$'
        $workflow | Should -Match 'pull_request:'
        $workflow | Should -Match 'branches:\s*\[main\]'
        $workflow | Should -Match 'pwsh'
    }

    It 'runs PSScriptAnalyzer through the CI helper with Error and Warning severities' {
        Test-Path -LiteralPath $script:AnalyzerScriptPath -PathType Leaf | Should -BeTrue
        $analyzerSource = Get-Content -LiteralPath $script:AnalyzerScriptPath -Raw
        $analyzerSource | Should -Match "Severity @\('Error', 'Warning'\)"
        $workflow = Get-Content -LiteralPath $script:CiWorkflowPath -Raw
        $workflow | Should -Match 'Invoke-PSScriptAnalyzerCI\.ps1'
    }

    It 'runs Pester against ./tests in the default workflow' {
        $workflow = Get-Content -LiteralPath $script:CiWorkflowPath -Raw
        $workflow | Should -Match 'Invoke-Pester -Path \./tests'
    }

    It 'passes PSScriptAnalyzer CI gate on repository PowerShell sources' {
        & pwsh.exe -NoProfile -File $script:AnalyzerScriptPath | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It 'validates module manifest without Connect-MgGraph in the manifest CI script' {
        $manifestSource = Get-Content -LiteralPath $script:ManifestScriptPath -Raw
        $manifestSource | Should -Match 'Test-ModuleManifest'
        $manifestSource | Should -Not -Match 'Connect-MgGraph'
    }
}
