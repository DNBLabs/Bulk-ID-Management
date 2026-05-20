<#
.SYNOPSIS
    Pester tests for Implementation Plan Task 4 Sub-task J (Task 4 closure verification).

.DESCRIPTION
    Validates Task 4 smoke behavior, checklist state in the task slice plan and parent
    implementation plan, and that Task 5+ scope was not started.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:TaskPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/tasks/task-4/PLAN-Task-4-Name-Mapping-MailNickname.md'
    $script:ImplementationPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/IMPLEMENTATION-PLAN.md'
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'

    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 4 Sub-task J - Get-MappedProvisioningIdentity closure smoke' {

    It 'maps Robert with GivenName Bob per CONTEXT display vs nickname rules' {
        $row = [PSCustomObject]@{
            SourceLineNumber = 3
            FirstName        = 'Robert'
            LastName         = 'Smith'
            Department       = 'IT'
            GivenName        = 'Bob'
        }

        $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row

        $mapped.GivenName | Should -Be 'Bob'
        $mapped.DisplayName | Should -Be 'Robert Smith'
        $mapped.MailNickname | Should -Be 'bob.smith'
    }

    It 'throws for invalid MailNickname with physical line in the message' {
        $row = [PSCustomObject]@{
            SourceLineNumber = 8
            FirstName        = 'Ada'
            LastName         = 'Lovelace'
            Department       = 'Engineering'
            MailNickname     = '!!!'
        }

        { Get-MappedProvisioningIdentity -ProvisioningRow $row } |
            Should -Throw -ExceptionType ([System.InvalidOperationException]) -PassThru |
            ForEach-Object { $_.Exception.Message } |
            Should -Match 'physical line 8'
    }
}

Describe 'Task 4 Sub-task J - closure checklist verification' {

    It 'marks Sub-task J acceptance and verification complete in the Task 4 slice plan' {
        $taskPlan = Get-Content -LiteralPath $script:TaskPlanPath -Raw
        $taskPlan | Should -Match '(?m)^- \[x\] Parent plan Task 4 acceptance criteria satisfied'
        $taskPlan | Should -Match '(?m)^- \[x\] No Task 5\+ code or tests introduced'
        $taskPlan | Should -Match '(?m)^- \[x\] `Invoke-Pester` Task 4 tests green'
        Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'Task4.Mapping.Security.Tests.ps1' -File |
            Should -Not -BeNullOrEmpty
    }

    It 'marks Task 4 completion checkpoints complete in the Task 4 slice plan' {
        $taskPlan = Get-Content -LiteralPath $script:TaskPlanPath -Raw
        $taskPlan | Should -Match '(?m)^- \[x\] \*\*`Invoke-Pester`\*\* passes for \*\*F\*\*'
        $taskPlan | Should -Match '(?m)^- \[x\] \*\*IMPLEMENTATION-PLAN\*\* Task 4 boxes updated\.'
        $taskPlan | Should -Match '(?m)^- \[x\] Ready for \*\*Task 5\*\*'
    }

    It 'marks Task 4 acceptance and verification bullets complete in the parent implementation plan' {
        $implementationPlan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $implementationPlan | Should -Match '(?m)^- \[x\] \*\*givenName\*\*, \*\*surname\*\*, \*\*displayName\*\* match \*\*CONTEXT\*\* rules for default columns\.'
        $implementationPlan | Should -Match '(?m)^- \[x\] Normalization covers documented edge cases \(accents, spaces\) with Pester examples\.'
        $implementationPlan | Should -Match '(?m)^- \[x\] Optional \*\*GivenName\*\* / \*\*Surname\*\* / \*\*DisplayName\*\* overrides active in v1'
        $implementationPlan | Should -Match '(?m)^- \[x\] Tests pass: Pester for name mapping and nickname cases\.'
    }

}
