<#
.SYNOPSIS
    Security regression tests for Task 13 operator entry.

.DESCRIPTION
    Validates absence of high-risk patterns in entry sources and that default report
    output from a dry run does not contain password material.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:ModuleRoot = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    $script:EntryFunctionPath = Join-Path -Path $script:ModuleRoot -ChildPath 'Public/Invoke-BulkIdentityProvisioning.ps1'
    $script:EntryScriptPath = Join-Path -Path $script:RepoRoot -ChildPath 'src/Scripts/Invoke-BulkIdentityProvisioning.ps1'
    Import-Module -Name (Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psm1') -Force -ErrorAction Stop

    $script:Task13TenantId = '11111111-1111-1111-1111-111111111111'
    $script:Task13ClientId = '22222222-2222-2222-2222-222222222222'
    $script:Task13Thumbprint = '0123456789abcdef0123456789abcdef01234567'
    $script:Task13TenantDomain = 'contoso.com'
    $script:Task13ItGroupId = '33333333-3333-3333-3333-333333333333'
}

function script:New-Task13SecuritySampleCsv {
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

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 13 - Invoke-BulkIdentityProvisioning security' {

    It 'does not use high-risk execution or network cmdlets in entry sources' {
        $paths = @($script:EntryFunctionPath, $script:EntryScriptPath)
        $dangerousPatterns = @(
            '(?i)\bInvoke-Expression\b'
            '(?i)\biex\b'
            '(?i)\bInvoke-WebRequest\b'
            '(?i)\bInvoke-RestMethod\b'
            '(?i)\bStart-Process\b'
        )

        foreach ($path in $paths) {
            Test-Path -LiteralPath $path -PathType Leaf | Should -BeTrue
            $text = Get-Content -LiteralPath $path -Raw
            foreach ($pattern in $dangerousPatterns) {
                $text | Should -Not -Match $pattern
            }
        }
    }

    It 'documents dry-run before mutating apply in entry help' {
        $text = Get-Content -LiteralPath $script:EntryFunctionPath -Raw
        $text | Should -Match 'dry-run before mutating apply'
        $text | Should -Match '-DryRun'
        $text | Should -Match '-WhatIf'
    }

    It 'delegates row reporting to Write-ProvisioningAggregateReport' {
        $text = Get-Content -LiteralPath $script:EntryFunctionPath -Raw
        $text | Should -Match 'Write-ProvisioningAggregateReport'
    }

    It 'does not emit password material in default dry-run console output' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'task13-security-dryrun.csv'
        New-Task13SecuritySampleCsv -Path $csvPath

        $context = [pscustomobject]@{
            CsvPath               = $csvPath
            TenantId              = $script:Task13TenantId
            ClientId              = $script:Task13ClientId
            CertificateThumbprint = $script:Task13Thumbprint
            TenantDomainSuffix    = $script:Task13TenantDomain
            ItMembershipGroupId   = $script:Task13ItGroupId
        }

        $emittedText = InModuleScope BulkIdentityManagement -ArgumentList $context {
            param([pscustomobject] $Context)

            function script:Select-MgProfile {
                param([Parameter(Mandatory)][string] $Name)
                [void] $Name
            }

            Mock Connect-ProvisioningGraph { }
            Mock Invoke-ProvisioningOrchestrator {
                $failedOutcome = New-ProvisioningRowOutcome `
                    -SourceLineNumber 2 `
                    -Status 'Failed' `
                    -Reason 'password=PlaintextSecret123!'

                return [pscustomobject]@{
                    RowOutcomes = @($failedOutcome)
                    ExitCode    = 1
                    DryRun      = $true
                }
            }

            $pipelineOutput = @(
                Invoke-BulkIdentityProvisioning `
                    -CsvPath $Context.CsvPath `
                    -TenantId $Context.TenantId `
                    -ClientId $Context.ClientId `
                    -CertificateThumbprint $Context.CertificateThumbprint `
                    -TenantDomainSuffix $Context.TenantDomainSuffix `
                    -ItMembershipGroupId $Context.ItMembershipGroupId `
                    -DryRun
            )

            return (($pipelineOutput | Where-Object { $_ -is [string] }) -join ' ')
        }

        $emittedText | Should -Not -BeNullOrEmpty
        $emittedText | Should -Not -Match '(?i)password'
        $emittedText | Should -Not -Match 'PlaintextSecret'
        $emittedText | Should -Not -Match 'SecureString'
    }
}
