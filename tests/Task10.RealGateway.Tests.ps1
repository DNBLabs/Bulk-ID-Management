<#
.SYNOPSIS
    Pester tests for New-ProvisioningGraphGateway operations (mocked Graph cmdlets).

.DESCRIPTION
    Validates Task 7 contract behavior against mocked Microsoft.Graph v1.0 cmdlets.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 10 - New-ProvisioningGraphGateway operations' {

    BeforeEach {
        InModuleScope BulkIdentityManagement {
            function script:Select-MgProfile {
                param(
                    [Parameter(Mandatory)]
                    [string] $Name
                )
                [void] $Name
            }
        }
    }

    It 'TestUpnExists returns $null when filter finds no users' {
        InModuleScope BulkIdentityManagement {
            Mock Get-MgUser { return @() }

            $gateway = New-ProvisioningGraphGateway
            $result = & $gateway.TestUpnExists 'missing@contoso.com'

            $result | Should -BeNullOrEmpty
            Should -Invoke Get-MgUser -Times 1 -Exactly -ParameterFilter {
                $Filter -like "*userPrincipalName eq 'missing@contoso.com'"
            }
        }
    }

    It 'TestUpnExists returns Object ID when exactly one user matches' {
        InModuleScope BulkIdentityManagement {
            Mock Get-MgUser {
                return @([pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111' })
            }

            $gateway = New-ProvisioningGraphGateway
            $result = & $gateway.TestUpnExists 'ada@contoso.com'

            $result | Should -Be '11111111-1111-1111-1111-111111111111'
        }
    }

    It 'TestUpnExists throws when multiple users match' {
        InModuleScope BulkIdentityManagement {
            Mock Get-MgUser {
                return @(
                    [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111' }
                    [pscustomobject]@{ Id = '22222222-2222-2222-2222-222222222222' }
                )
            }

            $gateway = New-ProvisioningGraphGateway
            {
                & $gateway.TestUpnExists 'dup@contoso.com'
            } | Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage '*multiple users*'
        }
    }

    It 'NewUser calls New-MgUser with password profile and returns Object ID' {
        InModuleScope BulkIdentityManagement {
            function script:New-MgUser {
                param(
                    [Parameter()]
                    [hashtable] $BodyParameter
                )

                $script:CapturedNewMgUserBody = $BodyParameter
                return [pscustomobject]@{ Id = '33333333-3333-3333-3333-333333333333' }
            }

            $gateway = New-ProvisioningGraphGateway
            $oid = & $gateway.NewUser @{
                userPrincipalName = 'new.user@contoso.com'
                mailNickname      = 'new.user'
                givenName         = 'New'
                surname           = 'User'
                displayName       = 'New User'
                department        = 'IT'
            }

            $oid | Should -Be '33333333-3333-3333-3333-333333333333'
            $script:CapturedNewMgUserBody | Should -Not -BeNullOrEmpty
            $script:CapturedNewMgUserBody.userPrincipalName | Should -Be 'new.user@contoso.com'
            $script:CapturedNewMgUserBody.passwordProfile.Password | Should -BeOfType [System.Security.SecureString]
            $script:CapturedNewMgUserBody.passwordProfile.ForceChangePasswordNextSignIn | Should -BeTrue
        }
    }

    It 'UpdateUser rejects unknown patch keys before Update-MgUser' {
        InModuleScope BulkIdentityManagement {
            Mock Update-MgUser {}

            $gateway = New-ProvisioningGraphGateway
            $userId = '44444444-4444-4444-4444-444444444444'
            {
                & $gateway.UpdateUser $userId @{ mailNickname = 'nope' }
            } | Should -Throw -ExceptionType ([System.InvalidOperationException])

            Should -Invoke Update-MgUser -Times 0 -Exactly
        }
    }

    It 'GetGroupById resolves group by Object ID' {
        InModuleScope BulkIdentityManagement {
            $groupId = '55555555-5555-5555-5555-555555555555'
            Mock Get-MgGroup {
                return [pscustomobject]@{ Id = $groupId; DisplayName = 'IT Members' }
            }

            $gateway = New-ProvisioningGraphGateway
            $group = & $gateway.GetGroupById $groupId

            $group.id | Should -Be $groupId
            Should -Invoke Get-MgGroup -Times 1 -Exactly -ParameterFilter {
                $GroupId -eq '55555555-5555-5555-5555-555555555555'
            }
        }
    }

    It 'TestGroupMembership returns $false when member filter is empty' {
        InModuleScope BulkIdentityManagement {
            Mock Get-MgGroupMember { return @() }

            $gateway = New-ProvisioningGraphGateway
            $userId = '66666666-6666-6666-6666-666666666666'
            $groupId = '77777777-7777-7777-7777-777777777777'
            $result = & $gateway.TestGroupMembership $userId $groupId

            $result | Should -BeFalse
            Should -Invoke Get-MgGroupMember -Times 1 -Exactly -ParameterFilter {
                $Filter -eq "id eq '$userId'"
            }
        }
    }

    It 'AddGroupMember skips New-MgGroupMember when user is already a member' {
        InModuleScope BulkIdentityManagement {
            Mock Get-MgGroupMember {
                return @([pscustomobject]@{ Id = '88888888-8888-8888-8888-888888888888' })
            }
            Mock New-MgGroupMember {}

            $gateway = New-ProvisioningGraphGateway
            $userId = '88888888-8888-8888-8888-888888888888'
            $groupId = '99999999-9999-9999-9999-999999999999'
            { & $gateway.AddGroupMember $userId $groupId } | Should -Not -Throw

            Should -Invoke New-MgGroupMember -Times 0 -Exactly
        }
    }
}
