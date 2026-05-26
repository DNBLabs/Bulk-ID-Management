<#
.SYNOPSIS
    Pester tests for Task 6 IT department rule predicate.

.DESCRIPTION
    Validates Test-ProvisioningDepartmentMatch: case-insensitive comparison of Department
    against configurable Target (default 'IT'), trim on both sides, null/empty returns $false.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 6 - IT department rule via Test-ProvisioningDepartmentMatch' {

    It 'returns $true for exact match IT with default target' {
        InModuleScope BulkIdentityManagement {
            Test-ProvisioningDepartmentMatch -Department 'IT' | Should -BeTrue
        }
    }

    It 'matches lowercase it against default target' {
        InModuleScope BulkIdentityManagement {
            Test-ProvisioningDepartmentMatch -Department 'it' | Should -BeTrue
        }
    }

    It 'matches mixed case It against default target' {
        InModuleScope BulkIdentityManagement {
            Test-ProvisioningDepartmentMatch -Department 'It' | Should -BeTrue
        }
    }

    It 'returns $false for non-matching department' {
        InModuleScope BulkIdentityManagement {
            Test-ProvisioningDepartmentMatch -Department 'Engineering' | Should -BeFalse
        }
    }

    It 'returns $false for empty string department' {
        InModuleScope BulkIdentityManagement {
            Test-ProvisioningDepartmentMatch -Department '' | Should -BeFalse
        }
    }

    It 'returns $false for null department' {
        InModuleScope BulkIdentityManagement {
            Test-ProvisioningDepartmentMatch -Department $null | Should -BeFalse
        }
    }

    It 'returns $false for whitespace-only department' {
        InModuleScope BulkIdentityManagement {
            Test-ProvisioningDepartmentMatch -Department '   ' | Should -BeFalse
        }
    }

    It 'trims whitespace on department before matching' {
        InModuleScope BulkIdentityManagement {
            Test-ProvisioningDepartmentMatch -Department ' IT ' | Should -BeTrue
        }
    }

    It 'trims whitespace on target before matching' {
        InModuleScope BulkIdentityManagement {
            Test-ProvisioningDepartmentMatch -Department 'IT' -Target ' IT ' | Should -BeTrue
        }
    }

    It 'matches custom target value' {
        InModuleScope BulkIdentityManagement {
            Test-ProvisioningDepartmentMatch -Department 'Finance' -Target 'Finance' | Should -BeTrue
        }
    }

    It 'matches custom target case-insensitively' {
        InModuleScope BulkIdentityManagement {
            Test-ProvisioningDepartmentMatch -Department 'finance' -Target 'FINANCE' | Should -BeTrue
        }
    }

    It 'returns $false when department does not match custom target' {
        InModuleScope BulkIdentityManagement {
            Test-ProvisioningDepartmentMatch -Department 'IT' -Target 'Finance' | Should -BeFalse
        }
    }
}
