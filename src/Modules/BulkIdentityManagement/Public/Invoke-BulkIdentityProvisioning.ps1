<#
.SYNOPSIS
    Operator entry point for bulk Entra ID provisioning from a CSV file.

.DESCRIPTION
    Imports the provisioning CSV, connects to Microsoft Graph with certificate credentials,
    builds the real Graph gateway, runs the apply orchestrator (dry run or mutating apply),
    and writes the aggregate row outcome report. Returns a result object whose ExitCode
    follows the batch error policy (non-zero when any row failed).

    Use -DryRun or -WhatIf to preview per-row actions without mutating the directory.
    Operators should dry-run before mutating apply.

.PARAMETER CsvPath
    Path to the provisioning CSV file.

.PARAMETER TenantId
    Entra tenant ID (GUID).

.PARAMETER ClientId
    App registration client ID (GUID).

.PARAMETER CertificateThumbprint
    SHA-1 certificate thumbprint (Thumbprint parameter set).

.PARAMETER CertificatePath
    Path to a .pfx or .p12 file (CertificatePath parameter set).

.PARAMETER CertificatePassword
    Optional SecureString password for the certificate file.

.PARAMETER TenantDomainSuffix
    Verified tenant domain suffix for UPN composition (e.g. contoso.com).

.PARAMETER ItMembershipGroupId
    Object ID (GUID) of the pre-created IT membership group.

.PARAMETER ItDepartmentTarget
    Department value that qualifies for IT membership ensure (default IT).

.PARAMETER UsageLocation
    Optional ISO 3166 alpha-2 usage location applied when creating new users.

.PARAMETER DryRun
    Read-only plan; no mutating Graph operations.

.PARAMETER WhatIf
    Alias for dry run (same behavior as -DryRun).

.PARAMETER UpdateExisting
    When set, updates limited attributes for existing users per CONTEXT re-run behavior.

.PARAMETER ShowIdentifiers
    Opt-in to include fuller UPN/object identifiers in console output (lab debugging only).

.OUTPUTS
    PSCustomObject with RowOutcomes, ExitCode, and DryRun flag from the orchestrator.

.EXAMPLE
    Invoke-BulkIdentityProvisioning `
        -CsvPath ./users.csv `
        -TenantId $tenantId -ClientId $clientId -CertificateThumbprint $thumb `
        -TenantDomainSuffix 'contoso.com' `
        -ItMembershipGroupId $itGroupId `
        -DryRun

.NOTES
    Requires Connect-ProvisioningGraph to succeed before building New-ProvisioningGraphGateway.
    Normative contract: CONTEXT.md at repository root.
#>

function Invoke-BulkIdentityProvisioning {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSupportsShouldProcess', '',
        Justification = 'WhatIf and DryRun implement CONTEXT dry-run semantics, not PowerShell ShouldProcess gating.')]
    [CmdletBinding(DefaultParameterSetName = 'Thumbprint')]
    [OutputType([pscustomobject])]
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
        [AllowNull()]
        [AllowEmptyString()]
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

    if (-not (Test-Path -LiteralPath $CsvPath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new("Provisioning CSV file not found: $CsvPath")
    }

    $effectiveDryRun = $DryRun -or $WhatIf
    $provisioningRows = @(Import-ProvisioningCsv -Path $CsvPath)

    $connectParams = @{
        TenantId = $TenantId
        ClientId = $ClientId
    }

    if ($PSCmdlet.ParameterSetName -eq 'Thumbprint') {
        $connectParams['CertificateThumbprint'] = $CertificateThumbprint
    }
    else {
        $connectParams['CertificatePath'] = $CertificatePath
        if ($null -ne $CertificatePassword) {
            $connectParams['CertificatePassword'] = $CertificatePassword
        }
    }

    Connect-ProvisioningGraph @connectParams

    $graphGateway = New-ProvisioningGraphGateway

    $orchestratorResult = Invoke-ProvisioningOrchestrator `
        -ProvisioningRows $provisioningRows `
        -GraphGateway $graphGateway `
        -TenantDomainSuffix $TenantDomainSuffix `
        -ItMembershipGroupId $ItMembershipGroupId `
        -DryRun:$effectiveDryRun `
        -UpdateExisting:$UpdateExisting `
        -ItDepartmentTarget $ItDepartmentTarget `
        -UsageLocation $UsageLocation `
        -ShowIdentifiers:$ShowIdentifiers

    Write-ProvisioningAggregateReport `
        -RowOutcomes $orchestratorResult.RowOutcomes `
        -ShowIdentifiers:$ShowIdentifiers

    return $orchestratorResult
}
