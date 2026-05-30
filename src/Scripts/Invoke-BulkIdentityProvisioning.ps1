<#
.SYNOPSIS
    Operator script entry for bulk Entra ID provisioning.

.DESCRIPTION
    Imports the BulkIdentityManagement module and forwards parameters to
    Invoke-BulkIdentityProvisioning. Exits with the orchestrator batch exit code.

    Dry-run before mutating apply: use -DryRun or -WhatIf to preview the plan.

.NOTES
    Normative contract: CONTEXT.md at repository root.
#>

#Requires -Version 7.2

[CmdletBinding(DefaultParameterSetName = 'Thumbprint')]
param(
    [Parameter(Mandatory)]
    [string] $CsvPath,

    [Parameter(Mandatory)]
    [string] $TenantId,

    [Parameter(Mandatory)]
    [string] $ClientId,

    [Parameter(Mandatory, ParameterSetName = 'Thumbprint')]
    [string] $CertificateThumbprint,

    [Parameter(Mandatory, ParameterSetName = 'CertificatePath')]
    [string] $CertificatePath,

    [Parameter(ParameterSetName = 'CertificatePath')]
    [securestring] $CertificatePassword,

    [Parameter(Mandatory)]
    [string] $TenantDomainSuffix,

    [Parameter(Mandatory)]
    [string] $ItMembershipGroupId,

    [Parameter()]
    [string] $ItDepartmentTarget = 'IT',

    [Parameter()]
    [string] $UsageLocation,

    [Parameter()]
    [switch] $DryRun,

    [Parameter()]
    [switch] $WhatIf,

    [Parameter()]
    [switch] $UpdateExisting,

    [Parameter()]
    [switch] $ShowIdentifiers
)

$ErrorActionPreference = 'Stop'

$moduleRoot = Join-Path -Path $PSScriptRoot -ChildPath '../Modules/BulkIdentityManagement'
$psm1Path = Join-Path -Path $moduleRoot -ChildPath 'BulkIdentityManagement.psm1'

if (-not (Test-Path -LiteralPath $psm1Path -PathType Leaf)) {
    throw [System.IO.FileNotFoundException]::new("Module not found at: $psm1Path")
}

Import-Module -Name $psm1Path -Force -ErrorAction Stop

$result = Invoke-BulkIdentityProvisioning @PSBoundParameters
exit $result.ExitCode
