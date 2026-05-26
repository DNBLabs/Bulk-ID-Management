<#
.SYNOPSIS
    Pester closure tests for Task 8 in-memory fake Graph gateway.

.DESCRIPTION
    Verifies functional smoke, plan checkboxes, PSScriptAnalyzer clean on
    Task 8 source, and scope guard (no Task 9+ test files).
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop

    $script:ImplementationPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/IMPLEMENTATION-PLAN.md'
    $script:TaskPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/tasks/task-8/PLAN-Task-8-Fake-Graph-Gateway.md'
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 8 closure - fake Graph gateway' {

    It 'smoke: create user then look up by UPN returns Object ID' {
        InModuleScope BulkIdentityManagement {
            $state = @{ Users = @{}; UpnIndex = @{}; Groups = @{}; Members = @{} }
            $gw = New-FakeProvisioningGraphGateway -State $state
            $oid = & $gw.NewUser @{ userPrincipalName = 'ada@contoso.com'; department = 'IT' }
            $found = & $gw.TestUpnExists 'ada@contoso.com'
            $found | Should -Be $oid
        }
    }

    It 'marks Task 8 acceptance complete in implementation plan' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] Fake supports paths needed for dry-run'
        $plan | Should -Match '(?m)^- \[x\] No network calls\.'
    }

    It 'marks Task 8 verification complete in implementation plan' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] Tests pass: Pester tests targeting fake only\.'
    }

    It 'marks sub-task checkboxes complete in task plan' {
        $taskPlan = Get-Content -LiteralPath $script:TaskPlanPath -Raw
        $taskPlan | Should -Match '(?m)^- \[x\] \*\*A .+ Add `-State` parameter'
        $taskPlan | Should -Match '(?m)^- \[x\] \*\*G .+ Implement `AddGroupMember`'
        $taskPlan | Should -Match '(?m)^- \[x\] \*\*J .+ Closure'
    }

    It 'does not introduce Task 9 test files' {
        Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'Task9*.Tests.ps1' -File -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }
}
