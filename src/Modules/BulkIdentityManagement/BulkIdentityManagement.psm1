<#
.SYNOPSIS
    PowerShell module root for Bulk Identity Management (Entra ID bulk provisioning).

.DESCRIPTION
    This module hosts CSV contract validation, identity derivation, IT department rules,
    a Microsoft Graph gateway, and apply orchestration. Exact gallery pins live in
    BulkIdentityManagement.psd1 RequiredModules.

    Normative contract: CONTEXT.md at repository root.

.NOTES
    Requires PowerShell 7.2+ (see BulkIdentityManagement.psd1 when present). Default CI does not call
    Microsoft Graph; the dependency exists for local and guarded apply paths.

    Security: At import time this file only dot-sources fixed *.ps1 children under Public/ and Private/
    beneath the module root (paths resolved and confined). Private scripts load in explicit phases
    (Shared, Csv, Identity, Graph, Reporting, Orchestration) so constants and retry policy initialize
    before consumers.
#>

$moduleRoot = $PSScriptRoot
$moduleRootResolved = (Resolve-Path -LiteralPath $moduleRoot).ProviderPath.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar)
$moduleRootPrefix = $moduleRootResolved + [System.IO.Path]::DirectorySeparatorChar

$dotSourceModuleScripts = {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]] $ScriptPaths
    )

    foreach ($scriptPath in $ScriptPaths) {
        $resolvedScript = (Resolve-Path -LiteralPath $scriptPath -ErrorAction Stop).ProviderPath
        if (-not $resolvedScript.StartsWith($moduleRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $message = "Refusing to dot-source module script outside module root: $resolvedScript"
            throw [System.InvalidOperationException]::new($message)
        }

        . $resolvedScript
    }
}

$dotSourceModuleFolder = {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Private', 'Public')]
        [string] $FolderName,

        [Parameter()]
        [string] $SubfolderName
    )

    $scriptDirectory = if ([string]::IsNullOrWhiteSpace($SubfolderName)) {
        Join-Path -Path $moduleRoot -ChildPath $FolderName
    }
    else {
        Join-Path -Path $moduleRoot -ChildPath $FolderName | Join-Path -ChildPath $SubfolderName
    }

    if (-not (Test-Path -LiteralPath $scriptDirectory -PathType Container)) {
        return @()
    }

    $scriptPaths = @(Get-ChildItem -LiteralPath $scriptDirectory -Filter '*.ps1' -File |
        Sort-Object -Property Name |
        ForEach-Object { $_.FullName })

    if ($scriptPaths.Count -gt 0) {
        . $dotSourceModuleScripts -ScriptPaths $scriptPaths
    }

    return $scriptPaths
}

$privatePhases = @(
    @{ Name = 'Csv'; Subfolder = 'Csv' }
    @{ Name = 'Identity'; Subfolder = 'Identity' }
    @{ Name = 'Reporting'; Subfolder = 'Reporting' }
    @{ Name = 'Graph'; Subfolder = 'Graph' }
    @{ Name = 'Orchestration'; Subfolder = 'Orchestration' }
)

# Shared helpers load first (cross-cutting, no subfolder).
. $dotSourceModuleFolder -FolderName 'Private' -SubfolderName 'Shared'

foreach ($phase in $privatePhases) {
    . $dotSourceModuleFolder -FolderName 'Private' -SubfolderName $phase.Subfolder
}

. $dotSourceModuleFolder -FolderName 'Public'

Export-ModuleMember -Function @(
    'Import-ProvisioningCsv'
    'Get-MappedProvisioningIdentity'
    'Get-DerivedUserPrincipalName'
    'Connect-ProvisioningGraph'
)
