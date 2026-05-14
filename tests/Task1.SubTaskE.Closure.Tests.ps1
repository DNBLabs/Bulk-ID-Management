<#
.SYNOPSIS
    Pester tests for Implementation Plan Task 1 Sub-task E (Task 1 closure verification).

.DESCRIPTION
    Validates closure checklist state for Task 1 only. These tests intentionally avoid Task 2+
    scope and assert that the Task 1 slice plan plus parent implementation checklist reflect
    completed foundation work before the repository moves on to the next numbered task.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:TaskPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/tasks/PLAN-Task-1-Foundation.md'
    $script:ImplementationPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/IMPLEMENTATION-PLAN.md'
}

Describe 'Task 1 Sub-task E - closure verification' {

    It 'marks Sub-task E acceptance and verification checkboxes complete in the Task 1 slice plan' {
        $taskPlan = Get-Content -LiteralPath $script:TaskPlanPath -Raw
        $taskPlan | Should -Match '(?m)^- \[x\] \*\*`Test-ModuleManifest`\*\* still succeeds after all edits\.'
        $taskPlan | Should -Match '(?m)^- \[x\] \*\*`git diff`\*\* review: no private keys, \*\*client secrets\*\*, populated \*\*`\.tfvars`\*\*, or production \*\*Entra\*\* authentication secrets\.'
        $taskPlan | Should -Match '(?m)^- \[x\] \*\*Task 1\*\* parent checklist in \*\*IMPLEMENTATION-PLAN\*\* can be marked complete'
        $taskPlan | Should -Match '(?m)^- \[x\] Manual: `Test-ModuleManifest` \+ `Import-Module` smoke'
        $taskPlan | Should -Match '(?m)^- \[x\] Manual: Grep / review diff for \*\*tenant ID\*\* usage'
    }

    It 'marks the Task 1 foundation checkpoint complete and does not mark Task 2 ready work as started' {
        $taskPlan = Get-Content -LiteralPath $script:TaskPlanPath -Raw
        $taskPlan | Should -Match '(?m)^- \[x\] \*\*Sub-tasks A.?E\*\* acceptance boxes satisfied\.'
        $taskPlan | Should -Match '(?m)^- \[x\] \*\*`pwsh`\*\* smoke: manifest valid, module imports\.'
        $taskPlan | Should -Match '(?m)^- \[x\] \*\*`\.gitignore`\*\* matches \*\*SEC\*\* / PRD intent\.'
        $taskPlan | Should -Match '(?m)^- \[x\] Ready for \*\*Task 2\*\* \(README\) or \*\*Task 3\*\* \(CSV\) in separate work'
    }

    It 'marks only Task 1 acceptance and verification bullets complete in the parent implementation plan' {
        $implementationPlan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $implementationPlan | Should -Match '(?m)^- \[x\] A repository-owned manifest lists \*\*exact\*\* module versions \(no floating \*\*Latest\*\*\)\.'
        $implementationPlan | Should -Match '(?m)^- \[x\] `\.gitignore` excludes common secret and credential paths documented in \*\*SEC\*\* / \*\*CONTEXT\*\*\.'
        $implementationPlan | Should -Match '(?m)^- \[x\] `pwsh` is documented as the supported runtime \(\*\*7\.2\+\*\*, \*\*7\.4\+\*\* preferred\)\.'
        $implementationPlan | Should -Match '(?m)^- \[x\] Manual: `Test-ModuleManifest` \(or equivalent\) succeeds on the manifest if a module manifest is present\.'
        $implementationPlan | Should -Match '(?m)^- \[x\] Manual: Confirm no real tenant IDs or secrets were added to tracked files\.'
        $implementationPlan | Should -Match '(?m)^- \[ \] \*\*README\*\* opens with a pointer to \*\*CONTEXT\.md\*\* as normative\.'
    }

    It 'does not introduce Task 2 artifacts or a root requirements.psd1 while closing Task 1' {
        Test-Path -LiteralPath (Join-Path -Path $script:RepoRoot -ChildPath 'README.md') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path -Path $script:RepoRoot -ChildPath 'requirements.psd1') | Should -BeFalse
    }
}
