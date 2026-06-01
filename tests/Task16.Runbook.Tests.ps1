<#
.SYNOPSIS
    Pester tests for Task 16 operator runbook documentation.

.DESCRIPTION
    Asserts docs/runbook.md documents prerequisites, dry run and apply commands,
    outcome interpretation, and batch error policy exit semantics per CONTEXT.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:RunbookPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/runbook.md'
}

Describe 'Task 16 - operator runbook' {

    It 'provides docs/runbook.md for operators' {
        Test-Path -LiteralPath $script:RunbookPath -PathType Leaf | Should -BeTrue
    }

    It 'documents batch error policy and non-zero exit when any row failed' {
        $runbook = Get-Content -LiteralPath $script:RunbookPath -Raw
        $runbook | Should -Match 'batch error policy'
        $runbook | Should -Match 'ExitCode'
        $runbook | Should -Match 'non-zero'
    }

    It 'documents prerequisites, dry run, apply, and sample CSV path' {
        $runbook = Get-Content -LiteralPath $script:RunbookPath -Raw
        $runbook | Should -Match 'User\.ReadWrite\.All'
        $runbook | Should -Match 'admin consent'
        $runbook | Should -Match '-DryRun'
        $runbook | Should -Match 'Invoke-BulkIdentityProvisioning'
        $runbook | Should -Match 'samples/provisioning-sample\.csv'
        $runbook | Should -Match 'ItMembershipGroupId'
        $runbook | Should -Match 'certificate'
    }

    It 'documents row outcome labels operators should expect' {
        $runbook = Get-Content -LiteralPath $script:RunbookPath -Raw
        $runbook | Should -Match 'Created'
        $runbook | Should -Match 'Skipped'
        $runbook | Should -Match 'MembershipEnsured'
        $runbook | Should -Match 'Failed'
    }
}
