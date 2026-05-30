<#
.SYNOPSIS
    Closure tests for Task 10 Phase 3 (real Graph gateway builder + profile).

.DESCRIPTION
    Verifies builder smoke, task plan Phase 3 checkboxes, IMPLEMENTATION-PLAN Phase 3
    lock checklist, PSScriptAnalyzer clean, and scope guard. See PLAN-Task-10-Real-Graph-Gateway.md.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    $script:ImplementationPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/IMPLEMENTATION-PLAN.md'
    $script:TaskPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/tasks/task-10/PLAN-Task-10-Real-Graph-Gateway.md'
    $script:GatewaySourcePath = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/Private/New-ProvisioningGraphGateway.ps1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop

    function script:Get-Task10PlanPhaseSection {
        param([Parameter(Mandatory)][string] $PlanPath)

        $lines = Get-Content -LiteralPath $PlanPath
        $startMatch = $lines | Select-String -Pattern '^### Phase 3: Builder \+ profile' | Select-Object -First 1
        $endMatch = $lines | Select-String -Pattern '^### Phase 4:' | Select-Object -First 1
        if (-not $startMatch -or -not $endMatch) {
            throw [System.InvalidOperationException]::new('Could not locate Task 10 plan Phase 3 section boundaries.')
        }

        return ($lines[($startMatch.LineNumber - 1)..($endMatch.LineNumber - 2)] -join [Environment]::NewLine)
    }
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 10 Phase 3 closure - real Graph gateway builder' {

    It 'smoke: builder returns six ScriptBlocks after profile selection' {
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
            $gateway['TestUpnExists'] | Should -BeOfType [scriptblock]
        }
    }

    It 'marks Task 10 builder-slice acceptance in implementation plan' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] No \*\*beta\*\* profile by default\.'
    }

    It 'marks Task 10 full CI verification in implementation plan' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] CI \(Task 10 complete\):'
    }

    It 'marks Implementation Plan Phase 3 lock checklist for Tasks 7-12' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] \*\*Task 7\*\* — Phase 3 lock complete\.'
        $plan | Should -Match '(?m)^- \[x\] \*\*Task 8\*\* — Phase 3 lock complete\.'
        $plan | Should -Match '(?m)^- \[x\] \*\*Task 9\*\* — Phase 3 lock complete\.'
        $plan | Should -Match '(?m)^- \[x\] \*\*Task 10\*\* — Phase 3 lock complete\.'
        $plan | Should -Match '(?m)^- \[x\] \*\*Task 11\*\* — Phase 3 lock complete\.'
        $plan | Should -Match '(?m)^- \[x\] \*\*Task 12\*\* — Phase 3 lock complete\.'
    }

    It 'marks Task 10 plan Phase 3 sub-tasks G, H, and H-security checked' {
        $phase3Section = Get-Task10PlanPhaseSection -PlanPath $script:TaskPlanPath
        $unchecked = [regex]::Matches($phase3Section, '- \[ \]')
        $unchecked.Count | Should -Be 0 -Because 'Phase 3 sub-tasks G-H-security should be [x]'
    }

    It 'PSScriptAnalyzer clean on Task 10 Phase 3 source and tests' {
        $paths = @(
            $script:GatewaySourcePath
            (Join-Path -Path $script:RepoRoot -ChildPath 'tests/Task10.Phase3.RealGatewayBuilder.Tests.ps1')
            (Join-Path -Path $script:RepoRoot -ChildPath 'tests/Task10.Phase3.RealGatewayBuilder.Security.Tests.ps1')
        )
        foreach ($path in $paths) {
            $violations = Invoke-ScriptAnalyzer -Path $path -Severity Warning, Error
            $violations | Should -BeNullOrEmpty -Because "PSScriptAnalyzer should be clean for $path"
        }
    }

    It 'does not introduce Task 13 test files' {
        $task13Tests = Get-ChildItem -Path (Join-Path -Path $script:RepoRoot -ChildPath 'tests') -Filter 'Task13*' -ErrorAction SilentlyContinue
        $task13Tests | Should -BeNullOrEmpty -Because 'Task 13 is out of scope for Task 10 Phase 3'
    }
}
