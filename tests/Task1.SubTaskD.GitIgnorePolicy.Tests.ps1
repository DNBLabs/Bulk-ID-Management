<#
.SYNOPSIS
    Pester tests for Implementation Plan Task 1 Sub-task D (.gitignore alignment).

.DESCRIPTION
    Validates observable git ignore behavior for SEC / PRD artifact classes: secret-bearing
    environment files, certificate material, Terraform local files, PowerShell transcripts,
    Azure-style token caches, and narrowly-scoped operator-local configuration files.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:GitIgnorePath = Join-Path -Path $script:RepoRoot -ChildPath '.gitignore'

    function Test-PathIgnoredByGit {
        <#
        .SYNOPSIS
            Checks whether git ignore rules ignore a repository-relative path.

        .DESCRIPTION
            Uses git check-ignore with --no-index so the test validates the pattern contract
            without requiring dummy files to be created in the working tree.

        .PARAMETER RelativePath
            Repository-relative path to check against .gitignore rules.

        .OUTPUTS
            Boolean. Returns true when git reports the path is ignored.
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string] $RelativePath
        )

        & git -C $script:RepoRoot check-ignore --quiet --no-index -- $RelativePath
        return ($LASTEXITCODE -eq 0)
    }
}

Describe 'Task 1 Sub-task D - .gitignore policy' {

    It 'has a repository root .gitignore' {
        Test-Path -LiteralPath $script:GitIgnorePath | Should -BeTrue
    }

    It 'ignores secret-bearing environment files while allowing the safe example template' {
        Test-PathIgnoredByGit -RelativePath '.env' | Should -BeTrue
        Test-PathIgnoredByGit -RelativePath '.env.local' | Should -BeTrue
        Test-PathIgnoredByGit -RelativePath '.env.production.local' | Should -BeTrue
        Test-PathIgnoredByGit -RelativePath '.env.example' | Should -BeFalse
    }

    It 'ignores certificate, key, client secret, and credential JSON artifacts' {
        foreach ($relativePath in @(
            'auth/app.pem'
            'auth/private.key'
            'auth/app.pfx'
            'auth/app.p12'
            'secrets/client_secret_notes.txt'
            'secrets/tenant-credentials.json'
        )) {
            Test-PathIgnoredByGit -RelativePath $relativePath | Should -BeTrue
        }
    }

    It 'ignores Terraform local state and populated tfvars while allowing tfvars examples' {
        Test-PathIgnoredByGit -RelativePath '.terraform/providers.lock' | Should -BeTrue
        Test-PathIgnoredByGit -RelativePath 'terraform.tfstate' | Should -BeTrue
        Test-PathIgnoredByGit -RelativePath 'terraform.tfstate.backup' | Should -BeTrue
        Test-PathIgnoredByGit -RelativePath 'prod.auto.tfvars' | Should -BeTrue
        Test-PathIgnoredByGit -RelativePath 'prod.tfvars.example' | Should -BeFalse
    }

    It 'ignores transcripts, scratch logs, and local Pester result artifacts' {
        Test-PathIgnoredByGit -RelativePath 'apply.log' | Should -BeTrue
        Test-PathIgnoredByGit -RelativePath 'transcript-apply.txt' | Should -BeTrue
        Test-PathIgnoredByGit -RelativePath 'apply.transcript.txt' | Should -BeTrue
        Test-PathIgnoredByGit -RelativePath 'testResults.xml' | Should -BeTrue
    }

    It 'ignores Azure-style local token/cache directories that may hold session material' {
        Test-PathIgnoredByGit -RelativePath '.azure/accessTokens.json' | Should -BeTrue
        Test-PathIgnoredByGit -RelativePath '.Azure/accessTokens.json' | Should -BeTrue
        Test-PathIgnoredByGit -RelativePath '.azcopy/session.db' | Should -BeTrue
    }

    It 'ignores narrowly-scoped operator-local parameter and settings files' {
        Test-PathIgnoredByGit -RelativePath 'operator.local.psd1' | Should -BeTrue
        Test-PathIgnoredByGit -RelativePath 'operator.parameters.local.json' | Should -BeTrue
        Test-PathIgnoredByGit -RelativePath 'operator.local.parameters.json' | Should -BeTrue
        Test-PathIgnoredByGit -RelativePath 'local.settings.json' | Should -BeTrue
    }

    It 'does not add unrelated broad binary or build-artifact ignore patterns' {
        $gitIgnoreText = Get-Content -LiteralPath $script:GitIgnorePath -Raw
        foreach ($pattern in @('node_modules/', 'dist/', 'build/', 'bin/', 'obj/', '*.zip')) {
            $gitIgnoreText | Should -Not -Match ([regex]::Escape($pattern))
        }
    }
}
