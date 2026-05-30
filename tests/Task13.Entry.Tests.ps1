<#
.SYNOPSIS
    Pester tests for Task 13 operator entry (Invoke-BulkIdentityProvisioning wiring).

.DESCRIPTION
    Verifies CSV import, Connect-ProvisioningGraph, New-ProvisioningGraphGateway,
    Invoke-ProvisioningOrchestrator, and Write-ProvisioningAggregateReport are wired
    with mocked Graph dependencies (no live tenant). Should -Invoke assertions run
    inside InModuleScope; -ModuleName Should -Invoke after InModuleScope can hang.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop

    $script:Task13TenantId = '11111111-1111-1111-1111-111111111111'
    $script:Task13ClientId = '22222222-2222-2222-2222-222222222222'
    $script:Task13Thumbprint = '0123456789abcdef0123456789abcdef01234567'
    $script:Task13TenantDomain = 'contoso.com'
    $script:Task13ItGroupId = '33333333-3333-3333-3333-333333333333'
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

function script:New-Task13SampleCsv {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $content = @(
        'FirstName,LastName,Department'
        'Ada,Lovelace,Engineering'
    ) -join "`n"
    Set-Content -LiteralPath $Path -Value $content -Encoding utf8NoBOM
}

function script:New-Task13EntryContext {
    param(
        [Parameter(Mandatory)]
        [string] $CsvPath,

        [switch] $DryRun,

        [switch] $UseWhatIfSwitch,

        [switch] $UpdateExisting,

        [switch] $ShowIdentifiers,

        [string] $UsageLocation,

        [string] $ItDepartmentTarget
    )

    return [pscustomobject]@{
        CsvPath               = $CsvPath
        TenantId              = $script:Task13TenantId
        ClientId              = $script:Task13ClientId
        CertificateThumbprint = $script:Task13Thumbprint
        TenantDomainSuffix    = $script:Task13TenantDomain
        ItMembershipGroupId   = $script:Task13ItGroupId
        DryRun                = [bool] $DryRun
        WhatIf                = [bool] $UseWhatIfSwitch
        UpdateExisting        = [bool] $UpdateExisting
        ShowIdentifiers       = [bool] $ShowIdentifiers
        UsageLocation         = $UsageLocation
        ItDepartmentTarget    = $ItDepartmentTarget
    }
}

Describe 'Task 13 - Invoke-BulkIdentityProvisioning' {

    It 'throws FileNotFoundException when the CSV path does not exist' {
        $context = New-Task13EntryContext -CsvPath (Join-Path -Path $TestDrive -ChildPath 'missing-provisioning.csv') -DryRun

        InModuleScope BulkIdentityManagement -ArgumentList $context {
            param([pscustomobject] $Context)

            $params = @{
                CsvPath               = $Context.CsvPath
                TenantId              = $Context.TenantId
                ClientId              = $Context.ClientId
                CertificateThumbprint = $Context.CertificateThumbprint
                TenantDomainSuffix    = $Context.TenantDomainSuffix
                ItMembershipGroupId   = $Context.ItMembershipGroupId
                DryRun                = $true
            }

            { Invoke-BulkIdentityProvisioning @params } |
                Should -Throw -ExceptionType ([System.IO.FileNotFoundException])
        }
    }

    It 'wires connect, real gateway builder, dry orchestration, and aggregate report' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'task13-wiring.csv'
        New-Task13SampleCsv -Path $csvPath
        $context = New-Task13EntryContext -CsvPath $csvPath -DryRun

        $result = InModuleScope BulkIdentityManagement -ArgumentList $context {
            param([pscustomobject] $Context)

            function script:Select-MgProfile {
                param([Parameter(Mandatory)][string] $Name)
                [void] $Name
            }

            Mock Connect-ProvisioningGraph { }
            Mock Invoke-ProvisioningOrchestrator {
                return [pscustomobject]@{
                    RowOutcomes = @()
                    ExitCode    = 0
                    DryRun      = $true
                }
            }
            Mock Write-ProvisioningAggregateReport { }

            $invokeResult = Invoke-BulkIdentityProvisioning `
                -CsvPath $Context.CsvPath `
                -TenantId $Context.TenantId `
                -ClientId $Context.ClientId `
                -CertificateThumbprint $Context.CertificateThumbprint `
                -TenantDomainSuffix $Context.TenantDomainSuffix `
                -ItMembershipGroupId $Context.ItMembershipGroupId `
                -DryRun

            Should -Invoke Connect-ProvisioningGraph -Times 1 -Exactly
            Should -Invoke Invoke-ProvisioningOrchestrator -Times 1 -Exactly `
                -ParameterFilter {
                    $DryRun -eq $true -and
                    $null -ne $GraphGateway -and
                    $GraphGateway.ContainsKey('TestUpnExists') -and
                    $GraphGateway.ContainsKey('AddGroupMember')
                }
            Should -Invoke Write-ProvisioningAggregateReport -Times 1 -Exactly

            return $invokeResult
        }

        $result.ExitCode | Should -Be 0
        $result.DryRun | Should -BeTrue
    }

    It 'treats -WhatIf as dry run for orchestration' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'task13-whatif.csv'
        New-Task13SampleCsv -Path $csvPath
        $context = New-Task13EntryContext -CsvPath $csvPath -UseWhatIfSwitch

        InModuleScope BulkIdentityManagement -ArgumentList $context {
            param([pscustomobject] $Context)

            function script:Select-MgProfile {
                param([Parameter(Mandatory)][string] $Name)
                [void] $Name
            }

            Mock Connect-ProvisioningGraph { }
            Mock Invoke-ProvisioningOrchestrator {
                return [pscustomobject]@{ RowOutcomes = @(); ExitCode = 0; DryRun = $true }
            }
            Mock Write-ProvisioningAggregateReport { }

            $null = Invoke-BulkIdentityProvisioning `
                -CsvPath $Context.CsvPath `
                -TenantId $Context.TenantId `
                -ClientId $Context.ClientId `
                -CertificateThumbprint $Context.CertificateThumbprint `
                -TenantDomainSuffix $Context.TenantDomainSuffix `
                -ItMembershipGroupId $Context.ItMembershipGroupId `
                -WhatIf

            Should -Invoke Invoke-ProvisioningOrchestrator -Times 1 -Exactly `
                -ParameterFilter { $DryRun -eq $true }
        }
    }

    It 'returns the orchestrator batch exit code' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'task13-exit.csv'
        New-Task13SampleCsv -Path $csvPath
        $context = New-Task13EntryContext -CsvPath $csvPath

        $result = InModuleScope BulkIdentityManagement -ArgumentList $context {
            param([pscustomobject] $Context)

            function script:Select-MgProfile {
                param([Parameter(Mandatory)][string] $Name)
                [void] $Name
            }

            Mock Connect-ProvisioningGraph { }
            Mock Invoke-ProvisioningOrchestrator {
                return [pscustomobject]@{
                    RowOutcomes = @(
                        [pscustomobject]@{ SourceLineNumber = 2; Status = 'Failed'; Reason = 'simulated' }
                    )
                    ExitCode    = 1
                    DryRun      = $false
                }
            }
            Mock Write-ProvisioningAggregateReport { }

            return (Invoke-BulkIdentityProvisioning `
                -CsvPath $Context.CsvPath `
                -TenantId $Context.TenantId `
                -ClientId $Context.ClientId `
                -CertificateThumbprint $Context.CertificateThumbprint `
                -TenantDomainSuffix $Context.TenantDomainSuffix `
                -ItMembershipGroupId $Context.ItMembershipGroupId)
        }

        $result.ExitCode | Should -Be 1
    }

    It 'forwards UpdateExisting, UsageLocation, ItDepartmentTarget, and ShowIdentifiers to the orchestrator' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'task13-forward.csv'
        New-Task13SampleCsv -Path $csvPath
        $context = New-Task13EntryContext -CsvPath $csvPath -UpdateExisting -ShowIdentifiers `
            -UsageLocation 'US' -ItDepartmentTarget 'Engineering'

        InModuleScope BulkIdentityManagement -ArgumentList $context {
            param([pscustomobject] $Context)

            function script:Select-MgProfile {
                param([Parameter(Mandatory)][string] $Name)
                [void] $Name
            }

            Mock Connect-ProvisioningGraph { }
            Mock Invoke-ProvisioningOrchestrator {
                return [pscustomobject]@{ RowOutcomes = @(); ExitCode = 0; DryRun = $false }
            }
            Mock Write-ProvisioningAggregateReport { }

            $params = @{
                CsvPath               = $Context.CsvPath
                TenantId              = $Context.TenantId
                ClientId              = $Context.ClientId
                CertificateThumbprint = $Context.CertificateThumbprint
                TenantDomainSuffix    = $Context.TenantDomainSuffix
                ItMembershipGroupId   = $Context.ItMembershipGroupId
                UpdateExisting        = $true
                UsageLocation         = $Context.UsageLocation
                ItDepartmentTarget    = $Context.ItDepartmentTarget
                ShowIdentifiers       = $true
            }

            $null = Invoke-BulkIdentityProvisioning @params

            Should -Invoke Invoke-ProvisioningOrchestrator -Times 1 -Exactly `
                -ParameterFilter {
                    $UpdateExisting -eq $true -and
                    $UsageLocation -eq 'US' -and
                    $ItDepartmentTarget -eq 'Engineering' -and
                    $ShowIdentifiers -eq $true
                }
        }
    }
}
