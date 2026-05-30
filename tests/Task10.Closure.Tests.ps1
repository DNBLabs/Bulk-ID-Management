<#
.SYNOPSIS
    Closure tests for full Task 10 (real Graph gateway + transient policy).

.DESCRIPTION
    Verifies IMPLEMENTATION-PLAN acceptance, task plan completion, PSScriptAnalyzer,
    and scope guard. See PLAN-Task-10-Real-Graph-Gateway.md.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    $script:ImplementationPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/IMPLEMENTATION-PLAN.md'
    $script:TaskPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/tasks/task-10/PLAN-Task-10-Real-Graph-Gateway.md'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 10 closure - real Graph gateway' {

    It 'smoke: builder returns six ScriptBlocks' {
        InModuleScope BulkIdentityManagement {
            function script:Select-MgProfile {
                param(
                    [Parameter(Mandatory)]
                    [string] $Name
                )
                [void] $Name
            }

            $gateway = New-ProvisioningGraphGateway
            $gateway.Keys.Count | Should -Be 6
            $gateway.TestUpnExists | Should -BeOfType [scriptblock]
        }
    }

    It 'marks full Task 10 acceptance criteria in implementation plan' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] No \*\*beta\*\* profile by default\.'
        $plan | Should -Match '(?m)^- \[x\] Retries are capped'
        $plan | Should -Match '(?m)^- \[x\] \*\*IT membership group\*\* resolved by \*\*Object ID\*\*'
    }

    It 'marks Task 10 full CI verification in implementation plan' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] CI \(Task 10 complete\):'
    }

    It 'marks Task 10 complete in Phase 3 status table' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '\| \*\*10\*\* \| Real gateway \+ graph transient policy \| \*\*Complete\*\* \|'
    }

    It 'PSScriptAnalyzer clean on Task 10 gateway and retry source' {
        $paths = @(
            (Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/Private/Graph/New-ProvisioningGraphGateway.ps1')
            (Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/Private/Graph/Invoke-ProvisioningGraphCommand.ps1')
        )
        foreach ($path in $paths) {
            $violations = Invoke-ScriptAnalyzer -Path $path -Severity Warning, Error
            $violations | Should -BeNullOrEmpty -Because "PSScriptAnalyzer should be clean for $path"
        }
    }

    It 'does not introduce Task 13 test files' {
        $task13Tests = Get-ChildItem -Path (Join-Path -Path $script:RepoRoot -ChildPath 'tests') -Filter 'Task13*' -ErrorAction SilentlyContinue
        $task13Tests | Should -BeNullOrEmpty
    }
}
