<#
.SYNOPSIS
    Redacts credential-like patterns from provisioning failure messages.

.DESCRIPTION
    Sanitizes exception text before it is stored on row outcomes or written to
    default output streams. Used by the orchestrator and display formatting.

.PARAMETER Message
    Raw failure message from an caught exception.

.OUTPUTS
    System.String safe for row outcome Reason and console output.

.NOTES
    Private function; not exported. See CONTEXT.md apply output hygiene.
#>

function Get-SanitizedProvisioningFailureReason {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Message
    )

    if ([string]::IsNullOrWhiteSpace($Message)) {
        return 'Operation failed.'
    }

    $sanitized = $Message `
        -replace '(?i)Bearer\s+\S+', 'Bearer [redacted]' `
        -replace '(?i)password\s*=\s*\S+', 'credential=[redacted]' `
        -replace '(?i)password', 'credential'

    if ($sanitized -match '(?i)password|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+') {
        return 'Operation failed.'
    }

    return $sanitized
}
