<#
.SYNOPSIS
    Connects to Microsoft Graph as the automation principal using certificate credentials.

.DESCRIPTION
    Validates tenant/client GUIDs, certificate thumbprint or PFX file, then calls
    Connect-MgGraph with the appropriate parameter set. Returns void on success;
    throws InvalidOperationException with a clear message on any failure.

    Two mutually exclusive parameter sets:
      Thumbprint    - looks up cert in the local certificate store by SHA-1 thumbprint.
      CertificatePath - loads an X509Certificate2 from a .pfx/.p12 file on disk.

    No client-secret path. No environment-variable fallback. No disconnect wrapper.
    See CONTEXT.md for the authentication session contract.

.PARAMETER TenantId
    Azure AD tenant ID (GUID format). Validated via [guid]::TryParse.

.PARAMETER ClientId
    App registration / service principal client ID (GUID format). Validated via [guid]::TryParse.

.PARAMETER CertificateThumbprint
    SHA-1 thumbprint of the certificate installed in the local certificate store.
    Must be a 40-character hexadecimal string.

.PARAMETER CertificatePath
    Path to a .pfx or .p12 file containing the certificate and private key.

.PARAMETER CertificatePassword
    Optional SecureString password for the PFX file. Omit for unprotected PFX exports.

.OUTPUTS
    None. Success is indicated by the absence of an exception.

.EXAMPLE
    Connect-ProvisioningGraph -TenantId $tid -ClientId $cid -CertificateThumbprint $thumb

.EXAMPLE
    Connect-ProvisioningGraph -TenantId $tid -ClientId $cid -CertificatePath ./app.pfx
#>
function Connect-ProvisioningGraph {
    [CmdletBinding(DefaultParameterSetName = 'Thumbprint')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Thumbprint')]
        [Parameter(Mandatory, ParameterSetName = 'CertificatePath')]
        [string] $TenantId,

        [Parameter(Mandatory, ParameterSetName = 'Thumbprint')]
        [Parameter(Mandatory, ParameterSetName = 'CertificatePath')]
        [string] $ClientId,

        [Parameter(Mandatory, ParameterSetName = 'Thumbprint')]
        [string] $CertificateThumbprint,

        [Parameter(Mandatory, ParameterSetName = 'CertificatePath')]
        [string] $CertificatePath,

        [Parameter(ParameterSetName = 'CertificatePath')]
        [securestring] $CertificatePassword
    )

    $parsedGuid = [guid]::Empty
    if (-not [guid]::TryParse($TenantId, [ref] $parsedGuid)) {
        throw [System.InvalidOperationException]::new(
            "TenantId '$TenantId' is not a valid GUID.")
    }
    if (-not [guid]::TryParse($ClientId, [ref] $parsedGuid)) {
        throw [System.InvalidOperationException]::new(
            "ClientId '$ClientId' is not a valid GUID.")
    }

    if ($PSCmdlet.ParameterSetName -eq 'Thumbprint') {
        if ($CertificateThumbprint -notmatch '^[0-9a-fA-F]{40}$') {
            throw [System.InvalidOperationException]::new(
                "CertificateThumbprint '$CertificateThumbprint' is not a valid 40-character hexadecimal SHA-1 thumbprint.")
        }

        try {
            Connect-MgGraph -ClientId $ClientId -TenantId $TenantId `
                -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop
        }
        catch {
            throw [System.InvalidOperationException]::new(
                "Failed to connect to Microsoft Graph for tenant '$TenantId' using certificate thumbprint: $($_.Exception.Message)",
                $_.Exception)
        }
    }
    else {
        if (-not (Test-Path -LiteralPath $CertificatePath -PathType Leaf)) {
            throw [System.InvalidOperationException]::new(
                "Certificate file not found at '$CertificatePath'.")
        }

        $extension = [System.IO.Path]::GetExtension($CertificatePath)
        if ($extension -notin '.pfx', '.p12') {
            throw [System.InvalidOperationException]::new(
                "Expected a .pfx or .p12 certificate file, got '$extension'. PEM is not supported in v1.")
        }

        try {
            $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
                (Resolve-Path -LiteralPath $CertificatePath).ProviderPath,
                $CertificatePassword)
        }
        catch {
            throw [System.InvalidOperationException]::new(
                "Failed to load certificate from '$CertificatePath': $($_.Exception.Message)",
                $_.Exception)
        }

        $connectSucceeded = $false
        try {
            if (-not $cert.HasPrivateKey) {
                throw [System.InvalidOperationException]::new(
                    "Certificate loaded from '$CertificatePath' does not contain a private key. Export the certificate with its private key as a PFX.")
            }

            try {
                Connect-MgGraph -ClientId $ClientId -TenantId $TenantId `
                    -Certificate $cert -NoWelcome -ErrorAction Stop
                $connectSucceeded = $true
            }
            catch {
                throw [System.InvalidOperationException]::new(
                    "Failed to connect to Microsoft Graph for tenant '$TenantId' using certificate file: $($_.Exception.Message)",
                    $_.Exception)
            }
        }
        finally {
            if (-not $connectSucceeded -and $null -ne $cert) {
                $cert.Dispose()
            }
        }
    }
}
