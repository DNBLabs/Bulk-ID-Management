<#
.SYNOPSIS
    PowerShell module root for Bulk Identity Management (Entra ID bulk provisioning).

.DESCRIPTION
    This module will host CSV contract validation, identity derivation, IT department rules,
    a Microsoft Graph gateway, and apply orchestration. Task 1 establishes a loadable module
    layout; exact gallery pins live in BulkIdentityManagement.psd1 RequiredModules.

    Normative contract: CONTEXT.md at repository root.

.NOTES
    Requires PowerShell 7.2+ (see BulkIdentityManagement.psd1 when present). Default CI does not call
    Microsoft Graph; the dependency exists for local and guarded apply paths.

    Security: At import time this file only dot-sources fixed *.ps1 children under Public/ and Private/
    beneath the module root (paths resolved and confined). No operator CSV paths, no expression-from-string,
    and no interactive network calls here; keep untrusted input handling in dedicated functions per CONTEXT.
#>

$moduleRoot = $PSScriptRoot
$moduleRootResolved = (Resolve-Path -LiteralPath $moduleRoot).ProviderPath.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar)
$moduleRootPrefix = $moduleRootResolved + [System.IO.Path]::DirectorySeparatorChar

# Dot-sourced at module scope so child scripts define module-scoped variables (not function-local).
$dotSourceModuleChildScripts = {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Private', 'Public')]
        [string] $FolderName
    )

    $scriptDirectory = Join-Path -Path $moduleRoot -ChildPath $FolderName
    if (-not (Test-Path -LiteralPath $scriptDirectory -PathType Container)) {
        return
    }

    Get-ChildItem -LiteralPath $scriptDirectory -Filter '*.ps1' -File |
        Sort-Object -Property Name |
        ForEach-Object {
            $resolvedScript = (Resolve-Path -LiteralPath $_.FullName).ProviderPath
            if (-not $resolvedScript.StartsWith($moduleRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $message = "Refusing to dot-source module script outside module root: $resolvedScript"
                throw [System.InvalidOperationException]::new($message)
            }

            . $resolvedScript
        }
}

. $dotSourceModuleChildScripts -FolderName Private
. $dotSourceModuleChildScripts -FolderName Public

Export-ModuleMember -Function @(
    'Import-ProvisioningCsv'
    'Get-MappedProvisioningIdentity'
)
