<#
.SYNOPSIS
    Closure tests for Task 9 - Authentication Session.
.DESCRIPTION
    Smoke test, plan checkboxes, PSScriptAnalyzer, scope guard. See PLAN-Task-9-Auth-Session.md.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Get-Module -Name BulkIdentityManagement | Remove-Module -Force
}

Describe 'Task 9 Closure' {

    It 'Connect-ProvisioningGraph is an exported command' {
        $cmd = Get-Command -Name 'Connect-ProvisioningGraph' -Module 'BulkIdentityManagement' -ErrorAction SilentlyContinue
        $cmd | Should -Not -BeNullOrEmpty
    }

    It 'Connect-ProvisioningGraph appears in FunctionsToExport in manifest' {
        $manifestPath = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psd1'
        $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
        $manifest.ExportedFunctions.Keys | Should -Contain 'Connect-ProvisioningGraph'
    }

    It 'Task 9 plan has all sub-tasks checked' {
        $planPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/tasks/task-9/PLAN-Task-9-Auth-Session.md'
        $planContent = Get-Content -Path $planPath -Raw
        $unchecked = [regex]::Matches($planContent, '- \[ \]')
        $unchecked.Count | Should -Be 0 -Because 'all sub-tasks should be marked [x]'
    }

    It 'PSScriptAnalyzer clean on Task 9 source file' {
        $srcFile = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/Public/Connect-ProvisioningGraph.ps1'
        $violations = Invoke-ScriptAnalyzer -Path $srcFile -Severity Warning, Error
        $violations | Should -BeNullOrEmpty
    }

    It 'does not introduce Task 13 test files' {
        $task13Tests = Get-ChildItem -Path (Join-Path -Path $script:RepoRoot -ChildPath 'tests') -Filter 'Task13*' -ErrorAction SilentlyContinue
        $task13Tests | Should -BeNullOrEmpty -Because 'Task 13 is out of scope for Task 9'
    }
}
