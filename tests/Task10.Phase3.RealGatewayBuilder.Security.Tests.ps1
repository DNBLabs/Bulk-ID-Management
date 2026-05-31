<#
.SYNOPSIS
    Security tests for Task 10 Phase 3 (real Graph gateway builder).

.DESCRIPTION
    Validates builder is private, pins v1.0 profile only, avoids secret leakage in
    error surfaces, and contains no hardcoded tenant identifiers. See CONTEXT.md.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    $script:SrcFile = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/Private/Graph/New-ProvisioningGraphGateway.ps1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 10 Phase 3 - New-ProvisioningGraphGateway security' {

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

    It 'is not an exported module command' {
        Get-Command -Name 'New-ProvisioningGraphGateway' -Module 'BulkIdentityManagement' -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }

    It 'is not listed in FunctionsToExport' {
        $manifestPath = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psd1'
        $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
        $manifest.ExportedFunctions.Keys | Should -Not -Contain 'New-ProvisioningGraphGateway'
    }

    It 'has no parameters on the builder (no construction-time injection surface)' {
        $parseErrors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:SrcFile,
            [ref]$tokens,
            [ref]$parseErrors)
        $parseErrors | Should -BeNullOrEmpty
        $functionAst = $ast.FindAll(
            { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] },
            $true) |
            Where-Object { $_.Name -eq 'New-ProvisioningGraphGateway' } |
            Select-Object -First 1
        $functionAst.Body.ParamBlock.Parameters.Count | Should -Be 0
    }

    It 'source pins Graph profile to v1.0 literal only' {
        $text = Get-Content -LiteralPath $script:SrcFile -Raw
        $text | Should -Match "-Name\s+'v1\.0'"
        $text | Should -Not -Match "Select-MgProfile\s+-Name\s+'beta'"
        $text | Should -Not -Match 'Select-MgProfile\s+-Name\s+\$'
    }

    It 'source does not hardcode tenant or client identifiers' {
        $text = Get-Content -LiteralPath $script:SrcFile -Raw
        $guidPattern = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
        [regex]::Matches($text, $guidPattern).Count | Should -Be 0
    }

    It 'source does not write credentials to output streams' {
        $text = Get-Content -LiteralPath $script:SrcFile -Raw
        $text | Should -Not -Match 'Write-Host.*password'
        $text | Should -Not -Match 'Write-Output.*SecureString'
        $text | Should -Not -Match 'ConvertFrom-SecureString'
    }

    It 'profile failure outer message does not echo inner secret material' {
        InModuleScope BulkIdentityManagement {
            Mock Select-MgProfile {
                throw [System.InvalidOperationException]::new('Bearer eyJhbGciOiJIUzI1NiJ9.fake-token')
            }

            $caught = $null
            try {
                New-ProvisioningGraphGateway | Out-Null
            }
            catch {
                $caught = $_.Exception
            }

            $caught | Should -Not -BeNullOrEmpty
            $caught.Message | Should -Not -Match 'Bearer'
            $caught.Message | Should -Not -Match 'eyJ'
            $caught.InnerException.Message | Should -Match 'Bearer'
        }
    }

    It 'rejects caller-supplied password keys on NewUser without echoing secret material' {
        InModuleScope BulkIdentityManagement {
            Mock Select-MgProfile {}

            $gateway = New-ProvisioningGraphGateway
            $message = $null
            try {
                [void] (& $gateway.NewUser @{
                    password          = 'PlaintextSecret123!'
                    userPrincipalName = 'x@y.com'
                })
            }
            catch {
                $message = $_.Exception.Message
            }

            $message | Should -Match 'password must not be supplied to NewUser'
            $message | Should -Not -Match 'PlaintextSecret'
        }
    }
}
