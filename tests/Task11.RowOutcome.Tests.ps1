<#
.SYNOPSIS
    Pester tests for Task 11 row outcome objects and reporting helpers.

.DESCRIPTION
    Validates row outcome factory, display redaction, aggregate exit code policy,
    and default output hygiene without passwords or identifiers.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 11 - provisioning row outcomes' {

    It 'creates a row outcome with canonical Created status' {
        InModuleScope BulkIdentityManagement {
            $outcome = New-ProvisioningRowOutcome -SourceLineNumber 2 -Status 'Created'
            $outcome.Status | Should -Be 'Created'
            $outcome.SourceLineNumber | Should -Be 2
        }
    }

    It 'rejects an unknown status label' {
        InModuleScope BulkIdentityManagement {
            {
                New-ProvisioningRowOutcome -SourceLineNumber 1 -Status 'Unknown'
            } | Should -Throw -ExceptionType ([System.ArgumentException])
        }
    }

    It 'formats default display without UPN or object id' {
        InModuleScope BulkIdentityManagement {
            $outcome = New-ProvisioningRowOutcome `
                -SourceLineNumber 3 `
                -Status 'Skipped' `
                -UserPrincipalName 'secret.user@contoso.com' `
                -ObjectId '11111111-1111-1111-1111-111111111111'
            $line = Format-ProvisioningRowOutcomeDisplayLine -RowOutcome $outcome
            $line | Should -Be 'Line 3: Skipped'
            $line | Should -Not -Match 'contoso'
            $line | Should -Not -Match '11111111'
        }
    }

    It 'includes UPN when ShowIdentifiers is enabled' {
        InModuleScope BulkIdentityManagement {
            $outcome = New-ProvisioningRowOutcome `
                -SourceLineNumber 4 `
                -Status 'Created' `
                -UserPrincipalName 'ada@contoso.com'
            $line = Format-ProvisioningRowOutcomeDisplayLine -RowOutcome $outcome -ShowIdentifiers
            $line | Should -Match 'ada@contoso.com'
        }
    }

    It 'never includes password text in formatted failure reason' {
        InModuleScope BulkIdentityManagement {
            $outcome = New-ProvisioningRowOutcome `
                -SourceLineNumber 5 `
                -Status 'Failed' `
                -Reason 'password=PlaintextSecret123!'
            $line = Format-ProvisioningRowOutcomeDisplayLine -RowOutcome $outcome
            $line | Should -Not -Match 'PlaintextSecret'
            $line | Should -Not -Match 'password'
        }
    }

    It 'returns exit code 1 when any row failed' {
        InModuleScope BulkIdentityManagement {
            $outcomes = @(
                (New-ProvisioningRowOutcome -SourceLineNumber 1 -Status 'Created')
                (New-ProvisioningRowOutcome -SourceLineNumber 2 -Status 'Failed' -Reason 'bad row')
            )
            Get-ProvisioningBatchExitCode -RowOutcomes $outcomes | Should -Be 1
        }
    }

    It 'returns exit code 0 when no row failed' {
        InModuleScope BulkIdentityManagement {
            $outcomes = @(
                (New-ProvisioningRowOutcome -SourceLineNumber 1 -Status 'Created')
                (New-ProvisioningRowOutcome -SourceLineNumber 2 -Status 'Skipped')
            )
            Get-ProvisioningBatchExitCode -RowOutcomes $outcomes | Should -Be 0
        }
    }
}
