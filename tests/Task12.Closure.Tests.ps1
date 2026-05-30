<#
.SYNOPSIS
    Closure tests for Task 12 apply orchestrator.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ImplementationPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/IMPLEMENTATION-PLAN.md'
    Import-Module -Name (Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1') -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 12 closure' {

    It 'marks Task 12 acceptance complete in implementation plan' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] \*\*Dry run\*\* performs no mutating calls'
        $plan | Should -Match '(?m)^- \[x\] \*\*Apply\*\* with fake mutates fake state'
        $plan | Should -Match '(?m)^- \[x\] \*\*IT membership ensure\*\* runs when user creation skipped but row qualifies'
    }

    It 'does not introduce Task 13 test files' {
        $task13 = Get-ChildItem -Path (Join-Path -Path $script:RepoRoot -ChildPath 'tests') -Filter 'Task13*' -ErrorAction SilentlyContinue
        $task13 | Should -BeNullOrEmpty
    }
}
