<#
.SYNOPSIS
    Security tests for Task 11 row outcomes and reporting helpers.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 11 - row outcome security' {

    It 'sanitizes Bearer tokens from failure reasons' {
        InModuleScope BulkIdentityManagement {
            $safe = Get-SanitizedProvisioningFailureReason -Message 'Bearer eyJhbGciOiJIUzI1NiJ9.secret'
            $safe | Should -Not -Match 'eyJ'
            $safe | Should -Not -Match 'Bearer eyJ'
        }
    }

    It 'does not write passwords via aggregate report output writer' {
        InModuleScope BulkIdentityManagement {
            $lines = [System.Collections.Generic.List[string]]::new()
            $writer = { param([string] $Line) $lines.Add($Line) | Out-Null }
            $outcome = New-ProvisioningRowOutcome `
                -SourceLineNumber 1 `
                -Status 'Failed' `
                -Reason 'password=PlaintextSecret123!'

            Write-ProvisioningAggregateReport -RowOutcomes @($outcome) -OutputWriter $writer

            ($lines -join ' ') | Should -Not -Match 'PlaintextSecret'
            ($lines -join ' ') | Should -Not -Match 'password'
        }
    }

    It 'keeps orchestrator and reporting helpers private' {
        @(
            'New-ProvisioningRowOutcome'
            'Format-ProvisioningRowOutcomeDisplayLine'
            'Get-ProvisioningBatchExitCode'
            'Write-ProvisioningAggregateReport'
            'Get-SanitizedProvisioningFailureReason'
        ) | ForEach-Object {
            Get-Command -Name $_ -Module 'BulkIdentityManagement' -ErrorAction SilentlyContinue |
                Should -BeNullOrEmpty -Because "$_ must not be exported"
        }
    }
}
