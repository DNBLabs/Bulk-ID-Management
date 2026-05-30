<#
.SYNOPSIS
    Pester tests for Task 10 Graph gateway private helpers.

.DESCRIPTION
    OData escape, property normalization, password generation, and GUID validation.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 10 - Graph helper functions' {

    It 'escapes apostrophes in OData literals' {
        InModuleScope BulkIdentityManagement {
            $escaped = ConvertTo-ProvisioningGraphODataLiteral -Value "o'brien@contoso.com"
            $escaped | Should -Be "o''brien@contoso.com"
        }
    }

    It 'rejects control characters in OData literals' {
        InModuleScope BulkIdentityManagement {
            {
                ConvertTo-ProvisioningGraphODataLiteral -Value "bad`nupn@contoso.com"
            } | Should -Throw -ExceptionType ([System.InvalidOperationException])
        }
    }

    It 'normalizes PascalCase and camelCase NewUser keys' {
        InModuleScope BulkIdentityManagement {
            $body = ConvertTo-ProvisioningGraphNewUserBody -Properties @{
                UserPrincipalName = 'ada@contoso.com'
                GivenName         = 'Ada'
                Surname           = 'Lovelace'
                DisplayName       = 'Ada Lovelace'
                MailNickname      = 'ada.lovelace'
                Department        = 'IT'
            }

            $body.userPrincipalName | Should -Be 'ada@contoso.com'
            $body.givenName | Should -Be 'Ada'
            $body.accountEnabled | Should -BeTrue
        }
    }

    It 'rejects unknown UpdateUser patch keys before Graph' {
        InModuleScope BulkIdentityManagement {
            {
                ConvertTo-ProvisioningGraphPatchBody -Properties @{ mailNickname = 'hack' }
            } | Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage '*not allowed for UpdateUser*'
        }
    }

    It 'generates a 32-character SecureString password with required character classes' {
        InModuleScope BulkIdentityManagement {
            $secure = New-ProvisioningGraphUserPassword
            $secure | Should -BeOfType [System.Security.SecureString]

            $credential = New-Object System.Net.NetworkCredential('', $secure)
            $plain = $credential.Password
            $plain.Length | Should -Be 32
            $plain | Should -Match '[A-Z]'
            $plain | Should -Match '[a-z]'
            $plain | Should -Match '[0-9]'
            $plain | Should -Match '[!@#$%&*\-_+=]'
        }
    }

    It 'rejects invalid group Object IDs' {
        InModuleScope BulkIdentityManagement {
            {
                Test-ProvisioningGraphObjectId -Id 'not-a-guid' -ParameterName 'GroupId'
            } | Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage '*GroupId*'
        }
    }
}
