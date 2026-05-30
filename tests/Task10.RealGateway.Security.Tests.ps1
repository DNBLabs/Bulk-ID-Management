<#
.SYNOPSIS
    Security tests for Task 10 real Graph gateway.

.DESCRIPTION
    Password redaction in errors, OData injection resistance, and GUID validation.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 10 - real Graph gateway security' {

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

    It 'does not include password material in Graph operation failure messages' {
        InModuleScope BulkIdentityManagement {
            Mock New-MgUser {
                throw [System.InvalidOperationException]::new('Password=SuperSecret123!')
            }

            $gateway = New-ProvisioningGraphGateway
            {
                & $gateway.NewUser @{
                    userPrincipalName = 'fail@contoso.com'
                    mailNickname      = 'fail'
                    givenName         = 'F'
                    surname           = 'L'
                    displayName       = 'FL'
                    department        = 'IT'
                }
            } | Should -Throw -ExceptionType ([System.InvalidOperationException])

            try {
                & $gateway.NewUser @{
                    userPrincipalName = 'fail@contoso.com'
                    mailNickname      = 'fail'
                    givenName         = 'F'
                    surname           = 'L'
                    displayName       = 'FL'
                    department        = 'IT'
                }
            }
            catch {
                $_.Exception.Message | Should -Not -Match 'SuperSecret'
                $_.Exception.Message | Should -Not -Match 'Password='
            }
        }
    }

    It 'uses escaped OData literal in TestUpnExists filter for apostrophe UPN' {
        InModuleScope BulkIdentityManagement {
            Mock Get-MgUser { return @() }

            $gateway = New-ProvisioningGraphGateway
            [void] (& $gateway.TestUpnExists "o'brien@contoso.com")

            Should -Invoke Get-MgUser -Times 1 -Exactly -ParameterFilter {
                $Filter -eq "userPrincipalName eq 'o''brien@contoso.com'"
            }
        }
    }

    It 'rejects invalid GUID before Get-MgGroup is invoked' {
        InModuleScope BulkIdentityManagement {
            Mock Get-MgGroup {}

            $gateway = New-ProvisioningGraphGateway
            {
                & $gateway.GetGroupById 'not-a-guid'
            } | Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage '*GroupId*'

            Should -Invoke Get-MgGroup -Times 0 -Exactly
        }
    }
}
