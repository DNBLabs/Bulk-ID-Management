<#
.SYNOPSIS
    Closure tests for Implementation Plan Phase 5 (Tasks 14-15 CI/CD and optional apply template).
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ImplementationPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/IMPLEMENTATION-PLAN.md'
}

Describe 'Task 14-15 Phase 5 closure' {

    It 'marks Task 14 acceptance criteria complete in implementation plan' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] CI fails on analyzer \*\*Warning\*\* severity per \*\*CONTEXT\*\*\.'
        $plan | Should -Match '(?m)^- \[x\] CI installs Graph modules only if needed for import analysis'
    }

    It 'marks Task 15 acceptance criteria complete in implementation plan' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] Not triggered on `pull_request` / `push` by default\.'
        $plan | Should -Match '(?m)^- \[x\] Documentation references \*\*SEC\*\* OIDC subject format\.'
    }

    It 'marks Phase 5 lock checklist for Tasks 14-15' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] \*\*Task 14\*\* - Phase 5 lock complete\.'
        $plan | Should -Match '(?m)^- \[x\] \*\*Task 15\*\* - Phase 5 lock complete\.'
        $plan | Should -Match '(?m)^- \[x\] \*\*Default CI validate-only\*\* . no tenant mutation from `ci\.yml`\.'
    }

    It 'marks checkpoint after Tasks 14-15 complete' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] CI green on representative branch\.'
        $plan | Should -Match '(?m)^- \[x\] No tenant mutation from default pipeline\.'
    }
}
