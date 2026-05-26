<#
.SYNOPSIS
    Pester tests for Task 8 in-memory fake Graph gateway.

.DESCRIPTION
    Validates New-FakeProvisioningGraphGateway with -State parameter provides
    working in-memory implementations of all six gateway operations per CONTEXT
    fake graph gateway internals.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 8 - Fake Graph gateway with in-memory state' {

    It 'builder accepts -State and returns hashtable with six keys' {
        InModuleScope BulkIdentityManagement {
            $state = @{ Users = @{}; UpnIndex = @{}; Groups = @{}; Members = @{} }
            $gw = New-FakeProvisioningGraphGateway -State $state
            $gw | Should -BeOfType [hashtable]
            $gw.Keys.Count | Should -Be 6
        }
    }

    Context 'TestUpnExists' {

        It 'returns $null for a UPN not in state' {
            InModuleScope BulkIdentityManagement {
                $state = @{ Users = @{}; UpnIndex = @{}; Groups = @{}; Members = @{} }
                $gw = New-FakeProvisioningGraphGateway -State $state
                $result = & $gw.TestUpnExists 'nobody@contoso.com'
                $result | Should -BeNullOrEmpty
            }
        }

        It 'returns Object ID for a seeded UPN' {
            InModuleScope BulkIdentityManagement {
                $state = @{
                    Users    = @{ 'obj-1' = @{ id = 'obj-1'; userPrincipalName = 'ada@contoso.com' } }
                    UpnIndex = @{ 'ada@contoso.com' = 'obj-1' }
                    Groups   = @{}
                    Members  = @{}
                }
                $gw = New-FakeProvisioningGraphGateway -State $state
                $result = & $gw.TestUpnExists 'ada@contoso.com'
                $result | Should -Be 'obj-1'
            }
        }

        It 'performs case-insensitive UPN lookup' {
            InModuleScope BulkIdentityManagement {
                $state = @{
                    Users    = @{ 'obj-1' = @{ id = 'obj-1' } }
                    UpnIndex = @{ 'ada@contoso.com' = 'obj-1' }
                    Groups   = @{}
                    Members  = @{}
                }
                $gw = New-FakeProvisioningGraphGateway -State $state
                $result = & $gw.TestUpnExists 'ADA@Contoso.COM'
                $result | Should -Be 'obj-1'
            }
        }
    }

    Context 'NewUser' {

        It 'stores user in state and returns an Object ID' {
            InModuleScope BulkIdentityManagement {
                $state = @{ Users = @{}; UpnIndex = @{}; Groups = @{}; Members = @{} }
                $gw = New-FakeProvisioningGraphGateway -State $state
                $oid = & $gw.NewUser @{ userPrincipalName = 'ada@contoso.com'; department = 'IT' }
                $oid | Should -Not -BeNullOrEmpty
                $state.Users.ContainsKey($oid) | Should -BeTrue
            }
        }

        It 'adds lowercase UPN to UpnIndex' {
            InModuleScope BulkIdentityManagement {
                $state = @{ Users = @{}; UpnIndex = @{}; Groups = @{}; Members = @{} }
                $gw = New-FakeProvisioningGraphGateway -State $state
                $oid = & $gw.NewUser @{ userPrincipalName = 'Ada@Contoso.COM' }
                $state.UpnIndex.ContainsKey('ada@contoso.com') | Should -BeTrue
                $state.UpnIndex['ada@contoso.com'] | Should -Be $oid
            }
        }

        It 'stored record contains caller fields plus id' {
            InModuleScope BulkIdentityManagement {
                $state = @{ Users = @{}; UpnIndex = @{}; Groups = @{}; Members = @{} }
                $gw = New-FakeProvisioningGraphGateway -State $state
                $oid = & $gw.NewUser @{ userPrincipalName = 'ada@contoso.com'; department = 'Engineering' }
                $record = $state.Users[$oid]
                $record['id'] | Should -Be $oid
                $record['department'] | Should -Be 'Engineering'
                $record['userPrincipalName'] | Should -Be 'ada@contoso.com'
            }
        }

        It 'throws InvalidOperationException on duplicate UPN' {
            InModuleScope BulkIdentityManagement {
                $state = @{
                    Users    = @{}
                    UpnIndex = @{ 'ada@contoso.com' = 'existing-id' }
                    Groups   = @{}
                    Members  = @{}
                }
                $gw = New-FakeProvisioningGraphGateway -State $state
                { & $gw.NewUser @{ userPrincipalName = 'ada@contoso.com' } } |
                    Should -Throw -ExceptionType ([System.InvalidOperationException])
            }
        }
    }

    Context 'UpdateUser' {

        It 'merges patch fields into existing user' {
            InModuleScope BulkIdentityManagement {
                $state = @{
                    Users    = @{ 'obj-1' = @{ id = 'obj-1'; department = 'Sales'; givenName = 'Ada' } }
                    UpnIndex = @{}
                    Groups   = @{}
                    Members  = @{}
                }
                $gw = New-FakeProvisioningGraphGateway -State $state
                & $gw.UpdateUser 'obj-1' @{ department = 'IT'; surname = 'Lovelace' }
                $state.Users['obj-1']['department'] | Should -Be 'IT'
                $state.Users['obj-1']['surname'] | Should -Be 'Lovelace'
                $state.Users['obj-1']['givenName'] | Should -Be 'Ada'
            }
        }

        It 'throws InvalidOperationException for unknown Object ID' {
            InModuleScope BulkIdentityManagement {
                $state = @{ Users = @{}; UpnIndex = @{}; Groups = @{}; Members = @{} }
                $gw = New-FakeProvisioningGraphGateway -State $state
                { & $gw.UpdateUser 'nonexistent' @{ department = 'IT' } } |
                    Should -Throw -ExceptionType ([System.InvalidOperationException])
            }
        }
    }

    Context 'GetGroupById' {

        It 'returns seeded group' {
            InModuleScope BulkIdentityManagement {
                $state = @{
                    Users    = @{}
                    UpnIndex = @{}
                    Groups   = @{ 'grp-1' = @{ id = 'grp-1'; displayName = 'IT Team' } }
                    Members  = @{}
                }
                $gw = New-FakeProvisioningGraphGateway -State $state
                $group = & $gw.GetGroupById 'grp-1'
                $group['displayName'] | Should -Be 'IT Team'
            }
        }

        It 'throws InvalidOperationException for unknown group' {
            InModuleScope BulkIdentityManagement {
                $state = @{ Users = @{}; UpnIndex = @{}; Groups = @{}; Members = @{} }
                $gw = New-FakeProvisioningGraphGateway -State $state
                { & $gw.GetGroupById 'nonexistent' } |
                    Should -Throw -ExceptionType ([System.InvalidOperationException])
            }
        }
    }

    Context 'TestGroupMembership' {

        It 'returns $false when user is not a member' {
            InModuleScope BulkIdentityManagement {
                $state = @{
                    Users    = @{}
                    UpnIndex = @{}
                    Groups   = @{ 'grp-1' = @{ id = 'grp-1' } }
                    Members  = @{}
                }
                $gw = New-FakeProvisioningGraphGateway -State $state
                $result = & $gw.TestGroupMembership 'user-1' 'grp-1'
                $result | Should -BeFalse
            }
        }

        It 'returns $true after member is added' {
            InModuleScope BulkIdentityManagement {
                $state = @{
                    Users    = @{}
                    UpnIndex = @{}
                    Groups   = @{ 'grp-1' = @{ id = 'grp-1' } }
                    Members  = @{}
                }
                $gw = New-FakeProvisioningGraphGateway -State $state
                & $gw.AddGroupMember 'user-1' 'grp-1'
                $result = & $gw.TestGroupMembership 'user-1' 'grp-1'
                $result | Should -BeTrue
            }
        }
    }

    Context 'AddGroupMember' {

        It 'is idempotent - second add does not throw' {
            InModuleScope BulkIdentityManagement {
                $state = @{
                    Users    = @{}
                    UpnIndex = @{}
                    Groups   = @{ 'grp-1' = @{ id = 'grp-1' } }
                    Members  = @{}
                }
                $gw = New-FakeProvisioningGraphGateway -State $state
                & $gw.AddGroupMember 'user-1' 'grp-1'
                { & $gw.AddGroupMember 'user-1' 'grp-1' } | Should -Not -Throw
                $state.Members['grp-1'].Count | Should -Be 1
            }
        }

        It 'throws InvalidOperationException when group not seeded' {
            InModuleScope BulkIdentityManagement {
                $state = @{ Users = @{}; UpnIndex = @{}; Groups = @{}; Members = @{} }
                $gw = New-FakeProvisioningGraphGateway -State $state
                { & $gw.AddGroupMember 'user-1' 'nonexistent' } |
                    Should -Throw -ExceptionType ([System.InvalidOperationException])
            }
        }
    }

    Context 'Builder convenience and state sharing' {

        It 'works with no -State parameter (empty defaults)' {
            InModuleScope BulkIdentityManagement {
                $gw = New-FakeProvisioningGraphGateway
                $result = & $gw.TestUpnExists 'nobody@contoso.com'
                $result | Should -BeNullOrEmpty
            }
        }

        It 'operations mutate the original state reference' {
            InModuleScope BulkIdentityManagement {
                $state = @{
                    Users    = @{}
                    UpnIndex = @{}
                    Groups   = @{ 'grp-1' = @{ id = 'grp-1' } }
                    Members  = @{}
                }
                $gw = New-FakeProvisioningGraphGateway -State $state
                $oid = & $gw.NewUser @{ userPrincipalName = 'ada@contoso.com' }
                $state.Users.Count | Should -Be 1
                $state.UpnIndex.Count | Should -Be 1
                & $gw.AddGroupMember $oid 'grp-1'
                $state.Members['grp-1'].Contains($oid) | Should -BeTrue
            }
        }
    }
}
