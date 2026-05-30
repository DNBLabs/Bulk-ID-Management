<#
.SYNOPSIS
    Closure tests for Task 11 row outcomes and reporting.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ImplementationPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/IMPLEMENTATION-PLAN.md'
    Import-Module -Name (Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1') -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 11 closure' {

    It 'marks Task 11 acceptance complete in implementation plan' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] Passwords never written to default streams\.'
        $plan | Should -Match '(?m)^- \[x\] \*\*ShowIdentifiers\*\* opt-in documented'
        $plan | Should -Match '(?m)^- \[x\] Exit code policy'
    }
}
