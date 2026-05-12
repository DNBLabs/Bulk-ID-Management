<#
.SYNOPSIS
    Run PSScriptAnalyzer against repository PowerShell sources for CI.

.DESCRIPTION
    Scans ./src and ./tests (when present) for Error and Warning severity findings and exits
    non-zero if any are reported. Aligns with CONTEXT / SEC: default CI must fail PSScriptAnalyzer
    on Error and Warning for .ps1 and .psm1 code.

.PARAMETER RepoRoot
    Optional repository root. Defaults to the parent of the .github directory containing this script.
#>
[CmdletBinding()]
param(
    [string] $RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $RepoRoot

$findings = @()
foreach ($relativePath in @('src', 'tests')) {
    $target = Join-Path -Path $RepoRoot -ChildPath $relativePath
    if (-not (Test-Path -LiteralPath $target)) {
        continue
    }
    $findings += @(Invoke-ScriptAnalyzer -Path $target -Recurse -Severity @('Error', 'Warning'))
}

if ($findings.Count -gt 0) {
    $findings | Format-Table -AutoSize
    exit 1
}

exit 0
