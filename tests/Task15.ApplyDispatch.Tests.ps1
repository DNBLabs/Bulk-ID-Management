<#
.SYNOPSIS
    Pester tests for Task 15 optional manual tenant workflow template.

.DESCRIPTION
    Asserts the apply-dispatch placeholder workflow is manual-only, targets the entra-apply
    GitHub Environment, and documents SEC OIDC subject format without PR/push triggers.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ApplyWorkflowPath = Join-Path -Path $script:RepoRoot -ChildPath '.github/workflows/apply-dispatch-placeholder.yml'
    $script:DefaultCiWorkflowPath = Join-Path -Path $script:RepoRoot -ChildPath '.github/workflows/ci.yml'
    $script:ReadmePath = Join-Path -Path $script:RepoRoot -ChildPath 'README.md'
    $script:SecPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/Design/SEC.md'
}

Describe 'Task 15 - optional manual apply workflow template' {

    It 'provides a separate apply-dispatch workflow file' {
        Test-Path -LiteralPath $script:ApplyWorkflowPath -PathType Leaf | Should -BeTrue
    }

    It 'triggers only on workflow_dispatch, not on push or pull_request' {
        $workflow = Get-Content -LiteralPath $script:ApplyWorkflowPath -Raw
        $workflow | Should -Match 'workflow_dispatch:'
        $workflow | Should -Not -Match '(?m)^\s*push:\s*$'
        $workflow | Should -Not -Match '(?m)^\s*pull_request:\s*$'
    }

    It 'targets the entra-apply GitHub Environment and documents SEC OIDC subject format' {
        $workflow = Get-Content -LiteralPath $script:ApplyWorkflowPath -Raw
        $workflow | Should -Match 'entra-apply'
        $workflow | Should -Match 'environment:entra-apply'
        $workflow | Should -Match 'docs/Design/SEC\.md'
    }

    It 'documents optional apply path and SEC OIDC subject in README' {
        $readme = Get-Content -LiteralPath $script:ReadmePath -Raw
        $readme | Should -Match 'apply-dispatch-placeholder'
        $readme | Should -Match 'environment:entra-apply'
        $readme | Should -Match 'docs/Design/SEC\.md'
    }

    It 'keeps default CI validate-only without workflow_dispatch apply on ci.yml' {
        $defaultCi = Get-Content -LiteralPath $script:DefaultCiWorkflowPath -Raw
        $defaultCi | Should -Not -Match 'workflow_dispatch:'
        $defaultCi | Should -Not -Match 'Invoke-BulkIdentityProvisioning'
    }
}
