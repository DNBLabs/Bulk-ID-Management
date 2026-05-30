<#
.SYNOPSIS
    Pester tests for Task 12 apply orchestrator against the fake Graph gateway.

.DESCRIPTION
    End-to-end batch scenarios for dry run and apply paths without live Graph.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop

    function script:New-TestProvisioningRow {
        param(
            [int] $SourceLineNumber = 2,
            [string] $FirstName = 'Ada',
            [string] $LastName = 'Lovelace',
            [string] $Department = 'Engineering'
        )

        return [pscustomobject]@{
            SourceLineNumber = $SourceLineNumber
            FirstName        = $FirstName
            LastName         = $LastName
            Department       = $Department
        }
    }

    function script:New-TestOrchestratorState {
        param(
            [string] $GroupId = '22222222-2222-2222-2222-222222222222'
        )

        return @{
            Users    = @{}
            UpnIndex = @{}
            Groups   = @{ $GroupId = @{ id = $GroupId; displayName = 'IT Members' } }
            Members  = @{ $GroupId = [System.Collections.Generic.HashSet[string]]::new() }
            GroupId  = $GroupId
        }
    }
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 12 - Invoke-ProvisioningOrchestrator' {

    It 'dry run does not mutate fake gateway user state' {
        $state = New-TestOrchestratorState
        InModuleScope BulkIdentityManagement -ArgumentList $state {
            param($State)
            $row = [pscustomobject]@{
                SourceLineNumber = 2
                FirstName        = 'Ada'
                LastName         = 'Lovelace'
                Department       = 'Engineering'
            }
            $gw = New-FakeProvisioningGraphGateway -State $State

            $result = Invoke-ProvisioningOrchestrator `
                -ProvisioningRows @($row) `
                -GraphGateway $gw `
                -TenantDomainSuffix 'contoso.com' `
                -ItMembershipGroupId $State.GroupId `
                -DryRun

            $result.DryRun | Should -BeTrue
            $State.Users.Count | Should -Be 0
            $result.RowOutcomes[0].Status | Should -Be 'Created'
        }
    }

    It 'apply creates a new user in fake gateway state' {
        $state = New-TestOrchestratorState
        InModuleScope BulkIdentityManagement -ArgumentList $state {
            param($State)
            $row = [pscustomobject]@{
                SourceLineNumber = 2
                FirstName        = 'Ada'
                LastName         = 'Lovelace'
                Department       = 'Engineering'
            }
            $gw = New-FakeProvisioningGraphGateway -State $State

            $result = Invoke-ProvisioningOrchestrator `
                -ProvisioningRows @($row) `
                -GraphGateway $gw `
                -TenantDomainSuffix 'contoso.com' `
                -ItMembershipGroupId $State.GroupId

            $State.Users.Count | Should -Be 1
            $result.RowOutcomes[0].Status | Should -Be 'Created'
            $result.ExitCode | Should -Be 0
        }
    }

    It 'apply skips an existing UPN by default' {
        $state = New-TestOrchestratorState
        InModuleScope BulkIdentityManagement -ArgumentList $state {
            param($State)
            $row = [pscustomobject]@{
                SourceLineNumber = 2
                FirstName        = 'Ada'
                LastName         = 'Lovelace'
                Department       = 'Engineering'
            }
            $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row
            $derived = Get-DerivedUserPrincipalName `
                -ProvisioningRow $row `
                -MappedProvisioningIdentity $mapped `
                -TenantDomainSuffix 'contoso.com' `
                -UpnExists { param([string] $Upn) $false }
            $existingId = 'existing-user-id'
            $State.UpnIndex[$derived.UserPrincipalName.ToLowerInvariant()] = $existingId
            $State.Users[$existingId] = @{
                id                = $existingId
                userPrincipalName = $derived.UserPrincipalName
            }
            $gw = New-FakeProvisioningGraphGateway -State $State

            $result = Invoke-ProvisioningOrchestrator `
                -ProvisioningRows @($row) `
                -GraphGateway $gw `
                -TenantDomainSuffix 'contoso.com' `
                -ItMembershipGroupId $State.GroupId

            $State.Users.Count | Should -Be 1
            $result.RowOutcomes[0].Status | Should -Be 'Skipped'
        }
    }

    It 'apply updates limited fields when UpdateExisting is set' {
        $state = New-TestOrchestratorState
        InModuleScope BulkIdentityManagement -ArgumentList $state {
            param($State)
            $row = [pscustomobject]@{
                SourceLineNumber = 2
                FirstName        = 'Ada'
                LastName         = 'Lovelace'
                Department       = 'Engineering'
            }
            $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row
            $derived = Get-DerivedUserPrincipalName `
                -ProvisioningRow $row `
                -MappedProvisioningIdentity $mapped `
                -TenantDomainSuffix 'contoso.com' `
                -UpnExists { param([string] $Upn) $false }
            $existingId = 'existing-user-id'
            $State.UpnIndex[$derived.UserPrincipalName.ToLowerInvariant()] = $existingId
            $State.Users[$existingId] = @{
                id                = $existingId
                userPrincipalName = $derived.UserPrincipalName
                department        = 'Legacy'
                givenName         = 'Old'
                surname           = 'Name'
                displayName       = 'Old Name'
            }
            $gw = New-FakeProvisioningGraphGateway -State $State

            $result = Invoke-ProvisioningOrchestrator `
                -ProvisioningRows @($row) `
                -GraphGateway $gw `
                -TenantDomainSuffix 'contoso.com' `
                -ItMembershipGroupId $State.GroupId `
                -UpdateExisting

            $result.RowOutcomes[0].Status | Should -Be 'Updated'
            $State.Users['existing-user-id']['department'] | Should -Be 'Engineering'
        }
    }

    It 'apply ensures IT membership when user creation was skipped' {
        $state = New-TestOrchestratorState
        InModuleScope BulkIdentityManagement -ArgumentList $state {
            param($State)
            $row = [pscustomobject]@{
                SourceLineNumber = 2
                FirstName        = 'Ada'
                LastName         = 'Lovelace'
                Department       = 'IT'
            }
            $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row
            $derived = Get-DerivedUserPrincipalName `
                -ProvisioningRow $row `
                -MappedProvisioningIdentity $mapped `
                -TenantDomainSuffix 'contoso.com' `
                -UpnExists { param([string] $Upn) $false }
            $userId = 'existing-user-id'
            $State.UpnIndex[$derived.UserPrincipalName.ToLowerInvariant()] = $userId
            $State.Users[$userId] = @{
                id                = $userId
                userPrincipalName = $derived.UserPrincipalName
                department        = 'IT'
            }
            $gw = New-FakeProvisioningGraphGateway -State $State

            $result = Invoke-ProvisioningOrchestrator `
                -ProvisioningRows @($row) `
                -GraphGateway $gw `
                -TenantDomainSuffix 'contoso.com' `
                -ItMembershipGroupId $State.GroupId

            $result.RowOutcomes[0].Status | Should -Be 'MembershipEnsured'
            $State.Members[$State.GroupId].Contains($userId) | Should -BeTrue
        }
    }

    It 'continues processing after a row failure and returns non-zero exit code' {
        $state = New-TestOrchestratorState
        InModuleScope BulkIdentityManagement -ArgumentList $state {
            param($State)
            $gw = New-FakeProvisioningGraphGateway -State $State
            $badRow = [pscustomobject]@{
                SourceLineNumber = 2
                FirstName        = 'Ada'
                LastName         = 'Lovelace'
                MailNickname     = '!!!'
                Department       = 'Engineering'
            }
            $goodRow = [pscustomobject]@{
                SourceLineNumber = 3
                FirstName        = 'Grace'
                LastName         = 'Hopper'
                Department       = 'Engineering'
            }

            $result = Invoke-ProvisioningOrchestrator `
                -ProvisioningRows @($badRow, $goodRow) `
                -GraphGateway $gw `
                -TenantDomainSuffix 'contoso.com' `
                -ItMembershipGroupId $State.GroupId

            $result.RowOutcomes.Count | Should -Be 2
            $result.RowOutcomes[0].Status | Should -Be 'Failed'
            $result.RowOutcomes[1].Status | Should -Be 'Created'
            $result.ExitCode | Should -Be 1
        }
    }
}
