<#
.SYNOPSIS
    Pester tests for Implementation Plan Task 3 Sub-task A (module layout and CSV constants).

.DESCRIPTION
    Validates Public/Private folders, canonical provisioning CSV header constants, dot-source
    wiring in the root module, empty public exports, and no Microsoft Graph usage in CSV scripts.
#>

BeforeAll {
    $repoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:RepoRoot = $repoRoot
    $script:ModuleRoot = Join-Path -Path $repoRoot -ChildPath 'src/Modules/BulkIdentityManagement'
    $script:Psm1Path = Join-Path -Path $script:ModuleRoot -ChildPath 'BulkIdentityManagement.psm1'
    $script:PublicDir = Join-Path -Path $script:ModuleRoot -ChildPath 'Public'
    $script:PrivateDir = Join-Path -Path $script:ModuleRoot -ChildPath 'Private'
    $script:ConstantsPath = Join-Path -Path $script:PrivateDir -ChildPath 'ProvisioningCsv.Constants.ps1'
    $script:ExpectedRequiredHeaders = @('FirstName', 'LastName', 'Department')
    $script:ExpectedOptionalHeaders = @(
        'MailNickname'
        'UserPrincipalName'
        'GivenName'
        'Surname'
        'DisplayName'
    )
}

Describe 'Task 3 Sub-task A - BulkIdentityManagement CSV module layout' {

    It 'provides Public and Private directories under the module root' {
        Test-Path -LiteralPath $PublicDir -PathType Container | Should -BeTrue
        Test-Path -LiteralPath $PrivateDir -PathType Container | Should -BeTrue
    }

    It 'stores canonical CSV header names in Private/ProvisioningCsv.Constants.ps1' {
        Test-Path -LiteralPath $ConstantsPath -PathType Leaf | Should -BeTrue
    }

    It 'dot-sources Private scripts before Public scripts in the root module' {
        $text = Get-Content -LiteralPath $Psm1Path -Raw
        $privateIndex = $text.IndexOf("-FolderName Private", [System.StringComparison]::Ordinal)
        $publicIndex = $text.IndexOf("-FolderName Public", [System.StringComparison]::Ordinal)
        $privateIndex | Should -BeGreaterThan -1
        $publicIndex | Should -BeGreaterThan -1
        $privateIndex | Should -BeLessThan $publicIndex
    }

    It 'loads canonical header constants into module scope on import' {
        $resolvedPsm1 = Resolve-Path -LiteralPath $Psm1Path
        $moduleInfo = Import-Module -Name $resolvedPsm1.Path -PassThru -Force
        try {
            $required = & $moduleInfo { $RequiredProvisioningCsvHeaderNames }
            $optional = & $moduleInfo { $OptionalProvisioningCsvHeaderNames }
            $required | Should -BeExactly $ExpectedRequiredHeaders
            $optional | Should -BeExactly $ExpectedOptionalHeaders
        }
        finally {
            Remove-Module -ModuleInfo $moduleInfo -Force -ErrorAction SilentlyContinue
        }
    }

    It 'does not reference Connect-MgGraph or Import-Module Microsoft.Graph in CSV layout scripts' {
        $graphAuthFiles = @('Connect-ProvisioningGraph.ps1')
        $paths = @($Psm1Path)
        if (Test-Path -LiteralPath $PrivateDir) {
            $paths += @(Get-ChildItem -LiteralPath $PrivateDir -Filter '*.ps1' -File |
                Where-Object { $_.Name -notin $graphAuthFiles } |
                ForEach-Object { $_.FullName })
        }
        if (Test-Path -LiteralPath $PublicDir) {
            $paths += @(Get-ChildItem -LiteralPath $PublicDir -Filter '*.ps1' -File |
                Where-Object { $_.Name -notin $graphAuthFiles } |
                ForEach-Object { $_.FullName })
        }
        foreach ($path in $paths) {
            $text = Get-Content -LiteralPath $path -Raw
            $text | Should -Not -Match '(?i)Connect-MgGraph'
            $text | Should -Not -Match '(?i)Import-Module\s+Microsoft\.Graph'
        }
    }
}
