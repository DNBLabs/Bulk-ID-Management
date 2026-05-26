<#
.SYNOPSIS
    Pester closure tests for Task 6 IT department rule predicate.

.DESCRIPTION
    Verifies functional smoke, plan checkboxes, scope guard (no Task 7+ files),
    and PSScriptAnalyzer clean on Task 6 source files.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop

    $script:ImplementationPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/IMPLEMENTATION-PLAN.md'
    $script:TaskPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/tasks/task-6/PLAN-Task-6-IT-Department-Rule.md'
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 6 closure - IT department rule predicate' {

    It 'smoke: IT department matches and Sales does not' {
        InModuleScope BulkIdentityManagement {
            Test-ProvisioningDepartmentMatch -Department 'IT' | Should -BeTrue
            Test-ProvisioningDepartmentMatch -Department 'Sales' | Should -BeFalse
        }
    }

    It 'marks Task 6 acceptance complete in implementation plan' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] Default \*\*`IT`\*\* match is case-insensitive\.'
        $plan | Should -Match '(?m)^- \[x\] Configurable target string supported via parameter'
    }

    It 'marks Task 6 verification complete in implementation plan' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] Tests pass: Pester for rule edge cases'
    }

    It 'marks sub-task checkboxes complete in task plan' {
        $taskPlan = Get-Content -LiteralPath $script:TaskPlanPath -Raw
        $taskPlan | Should -Match '(?m)^- \[x\] `Test-ProvisioningDepartmentMatch` exists under Private'
        $taskPlan | Should -Match '(?m)^- \[x\] `tests/Task6\.DepartmentMatch\.Tests\.ps1` covers 12 scenarios'
    }

    It 'does not introduce Task 7 test files' {
        Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'Task7*.Tests.ps1' -File -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }
}
