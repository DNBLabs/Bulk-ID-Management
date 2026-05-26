<#
.SYNOPSIS
    Pester tests for Task 7 Graph gateway contract (stub shape).

.DESCRIPTION
    Validates New-FakeProvisioningGraphGateway returns a hashtable with the documented
    six ScriptBlock entries per CONTEXT Graph gateway contract. Stubs throw 'not implemented'
    until Task 8 fills in fake logic.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 7 - Graph gateway contract via New-FakeProvisioningGraphGateway' {

    It 'returns a hashtable' {
        InModuleScope BulkIdentityManagement {
            $gw = New-FakeProvisioningGraphGateway
            $gw | Should -BeOfType [hashtable]
        }
    }

    It 'contains all six required gateway operation keys' {
        InModuleScope BulkIdentityManagement {
            $gw = New-FakeProvisioningGraphGateway
            $expected = @('TestUpnExists', 'NewUser', 'UpdateUser', 'GetGroupById', 'TestGroupMembership', 'AddGroupMember')
            foreach ($key in $expected) {
                $gw.ContainsKey($key) | Should -BeTrue -Because "gateway must have '$key'"
            }
            $gw.Keys.Count | Should -Be 6
        }
    }

    It 'provides a callable ScriptBlock for each operation' {
        InModuleScope BulkIdentityManagement {
            $gw = New-FakeProvisioningGraphGateway
            foreach ($key in $gw.Keys) {
                $gw[$key] | Should -BeOfType [scriptblock] -Because "'$key' must be a ScriptBlock"
            }
        }
    }

    It 'TestUpnExists stub throws NotImplementedException' {
        InModuleScope BulkIdentityManagement {
            $gw = New-FakeProvisioningGraphGateway
            { & $gw.TestUpnExists 'ada@contoso.com' } | Should -Throw -ExceptionType ([System.NotImplementedException])
        }
    }

    It 'NewUser stub throws NotImplementedException' {
        InModuleScope BulkIdentityManagement {
            $gw = New-FakeProvisioningGraphGateway
            { & $gw.NewUser @{ UserPrincipalName = 'ada@contoso.com' } } | Should -Throw -ExceptionType ([System.NotImplementedException])
        }
    }

    It 'UpdateUser stub throws NotImplementedException' {
        InModuleScope BulkIdentityManagement {
            $gw = New-FakeProvisioningGraphGateway
            { & $gw.UpdateUser 'object-id' @{ department = 'IT' } } | Should -Throw -ExceptionType ([System.NotImplementedException])
        }
    }

    It 'GetGroupById stub throws NotImplementedException' {
        InModuleScope BulkIdentityManagement {
            $gw = New-FakeProvisioningGraphGateway
            { & $gw.GetGroupById 'group-id' } | Should -Throw -ExceptionType ([System.NotImplementedException])
        }
    }

    It 'TestGroupMembership stub throws NotImplementedException' {
        InModuleScope BulkIdentityManagement {
            $gw = New-FakeProvisioningGraphGateway
            { & $gw.TestGroupMembership 'user-id' 'group-id' } | Should -Throw -ExceptionType ([System.NotImplementedException])
        }
    }

    It 'AddGroupMember stub throws NotImplementedException' {
        InModuleScope BulkIdentityManagement {
            $gw = New-FakeProvisioningGraphGateway
            { & $gw.AddGroupMember 'user-id' 'group-id' } | Should -Throw -ExceptionType ([System.NotImplementedException])
        }
    }
}
