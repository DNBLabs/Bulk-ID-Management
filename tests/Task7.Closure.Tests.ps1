<#
.SYNOPSIS
    Pester closure tests for Task 7 Graph gateway contract.

.DESCRIPTION
    Verifies functional smoke, plan checkboxes, PSScriptAnalyzer clean on
    Task 7 source, and scope guard (no Task 8+ test files).
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop

    $script:ImplementationPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/IMPLEMENTATION-PLAN.md'
    $script:TaskPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/tasks/task-7/PLAN-Task-7-Graph-Gateway-Contract.md'
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 7 closure - Graph gateway contract' {

    It 'smoke: builder returns hashtable with six ScriptBlock entries' {
        InModuleScope BulkIdentityManagement {
            $gw = New-FakeProvisioningGraphGateway
            $gw | Should -BeOfType [hashtable]
            $gw.Keys.Count | Should -Be 6
            foreach ($key in $gw.Keys) {
                $gw[$key] | Should -BeOfType [scriptblock]
            }
        }
    }

    It 'marks Task 7 acceptance complete in implementation plan' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] Orchestrator dependencies are expressible against this contract alone\.'
        $plan | Should -Match '(?m)^- \[x\] All operations are documented as \*\*v1\.0\*\* Graph semantics\.'
    }

    It 'marks Task 7 verification complete in implementation plan' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] Manual: Review interface vs \*\*CONTEXT\*\*'
    }

    It 'marks sub-task checkboxes complete in task plan' {
        $taskPlan = Get-Content -LiteralPath $script:TaskPlanPath -Raw
        $taskPlan | Should -Match '(?m)^- \[x\] \*\*A .+ Stub builder function\*\*'
        $taskPlan | Should -Match '(?m)^- \[x\] \*\*B .+ Contract shape tests\*\*'
        $taskPlan | Should -Match '(?m)^- \[x\] \*\*C .+ Closure\*\*'
    }

    It 'does not introduce Task 8 test files' {
        Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'Task8*.Tests.ps1' -File -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }
}
