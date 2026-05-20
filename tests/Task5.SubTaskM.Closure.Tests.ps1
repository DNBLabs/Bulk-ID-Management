<#
.SYNOPSIS
    Pester tests for Task 5 closure verification.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:TaskPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/tasks/task-5/PLAN-Task-5-UPN-Composition-Collision.md'
    $script:ImplementationPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/IMPLEMENTATION-PLAN.md'
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 5 Sub-task M - Get-DerivedUserPrincipalName closure smoke' {

    It 'derives jane.doe2 when base UPN is taken' {
        $row = [PSCustomObject]@{
            SourceLineNumber = 3
            FirstName        = 'Jane'
            LastName         = 'Doe'
            Department       = 'IT'
        }
        $mapped = [PSCustomObject]@{
            SourceLineNumber = 3
            GivenName          = 'Jane'
            Surname            = 'Doe'
            DisplayName        = 'Jane Doe'
            MailNickname       = 'jane.doe'
        }
        $taken = @{ 'jane.doe@contoso.com' = $true }

        $derived = Get-DerivedUserPrincipalName `
            -ProvisioningRow $row `
            -MappedProvisioningIdentity $mapped `
            -TenantDomainSuffix 'contoso.com' `
            -UpnExists { param($u) $taken.ContainsKey($u) }

        $derived.UserPrincipalName | Should -Be 'jane.doe2@contoso.com'
        $derived.AttemptCount | Should -Be 2
    }
}

Describe 'Task 5 Sub-task M - closure checklist verification' {

    It 'marks Task 5 acceptance complete and does not introduce Task 6 test files' {
        $implementationPlan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $implementationPlan | Should -Match '(?m)^- \[x\] Full UPN from CSV overrides nickname\+suffix path when \*\*UserPrincipalName\*\* column present\.'
        Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'Task6*.Tests.ps1' -File -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }

    It 'does not mark Task 6 acceptance complete' {
        $implementationPlan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $implementationPlan | Should -Match '(?m)^- \[ \] Default \*\*`IT`\*\* match is case-insensitive\.'
    }

    It 'includes Task5.Derivation.Security.Tests.ps1 in the test suite' {
        Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'Task5.Derivation.Security.Tests.ps1' -File |
            Should -Not -BeNullOrEmpty
    }

    It 'exports Get-DerivedUserPrincipalName' {
        (Get-Command -Module BulkIdentityManagement -Name 'Get-DerivedUserPrincipalName' -ErrorAction Stop) |
            Should -Not -BeNullOrEmpty
    }
}
