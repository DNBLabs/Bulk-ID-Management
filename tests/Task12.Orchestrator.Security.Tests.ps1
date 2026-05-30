<#
.SYNOPSIS
    Security tests for Task 12 apply orchestrator.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    $script:SrcFile = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/Private/Invoke-ProvisioningOrchestrator.ps1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 12 - orchestrator security' {

    It 'is not an exported module command' {
        Get-Command -Name 'Invoke-ProvisioningOrchestrator' -Module 'BulkIdentityManagement' -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }

    It 'rejects non-GUID IT membership group id before processing rows' {
        InModuleScope BulkIdentityManagement {
            $state = @{ Users = @{}; UpnIndex = @{}; Groups = @{}; Members = @{} }
            $gw = New-FakeProvisioningGraphGateway -State $state
            $row = [pscustomobject]@{
                SourceLineNumber = 2
                FirstName        = 'Ada'
                LastName         = 'Lovelace'
                Department       = 'IT'
            }

            {
                Invoke-ProvisioningOrchestrator `
                    -ProvisioningRows @($row) `
                    -GraphGateway $gw `
                    -TenantDomainSuffix 'contoso.com' `
                    -ItMembershipGroupId 'not-a-guid'
            } | Should -Throw -ExceptionType ([System.ArgumentException])
        }
    }

    It 'sanitizes Graph exception text stored on failed row outcomes' {
        InModuleScope BulkIdentityManagement {
            $state = @{
                Users    = @{}
                UpnIndex = @{}
                Groups   = @{ '22222222-2222-2222-2222-222222222222' = @{ id = '22222222-2222-2222-2222-222222222222' } }
                Members  = @{}
            }
            $gw = New-FakeProvisioningGraphGateway -State $state
            $gw.NewUser = {
                throw [System.InvalidOperationException]::new('Bearer eyJhbGciOiJIUzI1NiJ9.leaked-token')
            }.GetNewClosure()

            $row = [pscustomobject]@{
                SourceLineNumber = 2
                FirstName        = 'Ada'
                LastName         = 'Lovelace'
                Department       = 'Engineering'
            }

            $result = Invoke-ProvisioningOrchestrator `
                -ProvisioningRows @($row) `
                -GraphGateway $gw `
                -TenantDomainSuffix 'contoso.com' `
                -ItMembershipGroupId '22222222-2222-2222-2222-222222222222'

            $result.RowOutcomes[0].Status | Should -Be 'Failed'
            $result.RowOutcomes[0].Reason | Should -Not -Match 'eyJ'
            $result.RowOutcomes[0].Reason | Should -Not -Match 'Bearer eyJ'
        }
    }

    It 'source does not write row data to output streams directly' {
        $text = Get-Content -LiteralPath $script:SrcFile -Raw
        $text | Should -Not -Match 'Write-Host'
        $text | Should -Not -Match 'Write-Output.*UserPrincipalName'
    }
}
