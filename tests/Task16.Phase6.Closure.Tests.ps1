<#
.SYNOPSIS
    Closure tests for Implementation Plan Phase 6 (Tasks 16-17 samples and lab hardening).
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ImplementationPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/IMPLEMENTATION-PLAN.md'
}

Describe 'Task 16-17 Phase 6 closure' {

    It 'marks Task 16 acceptance criteria complete in implementation plan' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] Sample uses fake names only; no real tenant identifiers\.'
        $plan | Should -Match '(?m)^- \[x\] Runbook includes \*\*batch error policy\*\* and exit code semantics\.'
    }

    It 'marks Task 17 acceptance criteria complete in implementation plan' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] Checklist covers \*\*CONTEXT\*\* behaviors not fully asserted in unit tests\.'
    }

    It 'marks Phase 6 lock checklist for Tasks 16-17' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] \*\*Task 16\*\* - Phase 6 lock complete\.'
        $plan | Should -Match '(?m)^- \[x\] \*\*Task 17\*\* - Phase 6 lock complete\.'
        $plan | Should -Match '(?m)^- \[x\] \*\*Sample CSV \+ runbook linked from README\.\*\*'
    }

    It 'marks v1 implementation checkpoint complete' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] All tasks.+acceptance criteria satisfied\.'
        $plan | Should -Match '(?m)^- \[x\] \*\*CONTEXT\*\* behaviors traceable to tests or documented manual checks\.'
    }
}
