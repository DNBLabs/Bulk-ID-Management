<#
.SYNOPSIS
    Pester tests for Task 17 lab integration checklist (non-CI human verification).

.DESCRIPTION
    Asserts docs/lab-integration-checklist.md covers live-tenant behaviors that unit tests
    do not fully exercise: throttling, IT membership idempotency, UpdateExisting scope, password hygiene.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ChecklistPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/lab-integration-checklist.md'
}

Describe 'Task 17 - lab integration checklist' {

    It 'provides a human-only lab checklist document' {
        Test-Path -LiteralPath $script:ChecklistPath -PathType Leaf | Should -BeTrue
        $content = Get-Content -LiteralPath $script:ChecklistPath -Raw
        $content | Should -Match 'non-CI'
    }

    It 'covers throttling retry behavior for live Graph apply' {
        $content = Get-Content -LiteralPath $script:ChecklistPath -Raw
        $content | Should -Match 'throttl'
        $content | Should -Match 'Retry-After'
    }

    It 'covers IT membership ensure idempotency on re-run' {
        $content = Get-Content -LiteralPath $script:ChecklistPath -Raw
        $content | Should -Match 'IT membership ensure'
        $content | Should -Match 'MembershipEnsured'
        $content | Should -Match 'idempotent'
    }

    It 'covers UpdateExisting limited attribute scope' {
        $content = Get-Content -LiteralPath $script:ChecklistPath -Raw
        $content | Should -Match 'UpdateExisting'
        $content | Should -Match 'department'
        $content | Should -Match 'givenName'
    }

    It 'covers password material not appearing in default logs' {
        $content = Get-Content -LiteralPath $script:ChecklistPath -Raw
        $content | Should -Match 'password'
        $content | Should -Match 'ShowIdentifiers'
    }
}
