<#
.SYNOPSIS
    Pester tests for Task 10 Phase 3 (real Graph gateway builder and profile).

.DESCRIPTION
    Verifies New-ProvisioningGraphGateway selects Graph v1.0 profile and returns the
    six-entry ScriptBlock contract. Mocks Select-MgProfile; no live Graph calls.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 10 Phase 3 - New-ProvisioningGraphGateway builder' {

    It 'returns six ScriptBlock operations when Select-MgProfile is unavailable (Graph SDK 2.x)' {
        InModuleScope BulkIdentityManagement {
            $gateway = New-ProvisioningGraphGateway

            $gateway | Should -BeOfType [hashtable]
            $gateway.Keys.Count | Should -Be 6
        }
    }

    It 'selects Graph v1.0 profile when Select-MgProfile is available' {
        InModuleScope BulkIdentityManagement {
            function script:Select-MgProfile {
                param([Parameter(Mandatory)][string] $Name)
                [void] $Name
            }
            Mock Select-MgProfile {}

            $gateway = New-ProvisioningGraphGateway

            Should -Invoke Select-MgProfile -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'v1.0'
            }

            $gateway | Should -BeOfType [hashtable]

            $expectedKeys = @(
                'TestUpnExists', 'NewUser', 'UpdateUser',
                'GetGroupById', 'TestGroupMembership', 'AddGroupMember'
            )
            foreach ($key in $expectedKeys) {
                $gateway.ContainsKey($key) | Should -BeTrue -Because "gateway must expose '$key'"
                $gateway[$key] | Should -BeOfType [scriptblock] -Because "'$key' must be a ScriptBlock"
            }
            $gateway.Keys.Count | Should -Be 6
        }
    }

    It 'wraps Select-MgProfile failure in InvalidOperationException' {
        InModuleScope BulkIdentityManagement {
            function script:Select-MgProfile {
                param([Parameter(Mandatory)][string] $Name)
                [void] $Name
            }
            Mock Select-MgProfile {
                throw [System.InvalidOperationException]::new('Profile v1.0 is not available.')
            }

            {
                New-ProvisioningGraphGateway
            } | Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage '*v1.0*'

            Should -Invoke Select-MgProfile -Times 1 -Exactly
        }
    }
}
