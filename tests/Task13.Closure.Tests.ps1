<#
.SYNOPSIS
    Closure tests for Task 13 operator entry script.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ImplementationPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/IMPLEMENTATION-PLAN.md'
    $script:EntryScriptPath = Join-Path -Path $script:RepoRoot -ChildPath 'src/Scripts/Invoke-BulkIdentityProvisioning.ps1'
    Import-Module -Name (Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1') -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 13 closure' {

    It 'marks Task 13 acceptance criteria complete in implementation plan' {
        $plan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $plan | Should -Match '(?m)^- \[x\] Parameters align with \*\*CONTEXT\*\*'
        $plan | Should -Match '(?m)^- \[x\] New users: random password'
    }

    It 'provides the operator script entry under src/Scripts' {
        Test-Path -LiteralPath $script:EntryScriptPath -PathType Leaf | Should -BeTrue
    }

    It 'exports Invoke-BulkIdentityProvisioning from the module' {
        Get-Command -Module BulkIdentityManagement -Name Invoke-BulkIdentityProvisioning -ErrorAction Stop |
            Should -Not -BeNullOrEmpty
    }

    It 'keeps gateway builders private' {
        {
            Get-Command -Module BulkIdentityManagement -Name New-ProvisioningGraphGateway -ErrorAction Stop
        } | Should -Throw
        {
            Get-Command -Module BulkIdentityManagement -Name New-FakeProvisioningGraphGateway -ErrorAction Stop
        } | Should -Throw
    }
}
