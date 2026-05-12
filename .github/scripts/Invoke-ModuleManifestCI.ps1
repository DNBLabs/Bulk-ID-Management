<#
.SYNOPSIS
    CI step: validate the BulkIdentityManagement module manifest when it exists.

.DESCRIPTION
    When src/Modules/BulkIdentityManagement/BulkIdentityManagement.psd1 is present, reads the
    exact Microsoft.Graph version from docs/tasks/MicrosoftGraph.psgallery.version.txt, installs
    that version from PSGallery (so Test-ModuleManifest can resolve RequiredModules), and runs
    Test-ModuleManifest. Does not call Microsoft Graph APIs. If the manifest file is absent, exits 0.
#>
[CmdletBinding()]
param(
    [string] $RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

function Invoke-ModuleManifestCIStep {
    <#
    .SYNOPSIS
        Runs manifest validation and optional Graph install for CI.

    .DESCRIPTION
        If the module manifest path exists, resolves the pinned Microsoft.Graph version, installs it,
        and invokes Test-ModuleManifest. Throws if the pin file is missing or malformed when a manifest exists.

    .PARAMETER RepoRoot
        Absolute path to the repository root.

    .OUTPUTS
        None. Exits the process with code 0 on success or throws (non-zero exit) on failure.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RepoRoot
    )

    $ErrorActionPreference = 'Stop'
    Set-Location -LiteralPath $RepoRoot

    $manifestPath = Join-Path -Path $RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psd1'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        Write-Output 'No module manifest in repository; skipping Test-ModuleManifest and Graph gallery install.'
        exit 0
    }

    $pinPath = Join-Path -Path $RepoRoot -ChildPath 'docs/tasks/MicrosoftGraph.psgallery.version.txt'
    if (-not (Test-Path -LiteralPath $pinPath)) {
        throw 'Pin record missing at docs/tasks/MicrosoftGraph.psgallery.version.txt (required for manifest validation).'
    }

    $pinVersion = (Get-Content -LiteralPath $pinPath -Raw).Trim()
    if ($pinVersion -notmatch '^\d+\.\d+\.\d+$') {
        throw "Pin record must be a single numeric x.y.z line; got: $pinVersion"
    }

    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module -Name Microsoft.Graph -RequiredVersion $pinVersion -Repository PSGallery -Scope CurrentUser -Force -SkipPublisherCheck
    Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
}

Invoke-ModuleManifestCIStep -RepoRoot $RepoRoot
exit 0
