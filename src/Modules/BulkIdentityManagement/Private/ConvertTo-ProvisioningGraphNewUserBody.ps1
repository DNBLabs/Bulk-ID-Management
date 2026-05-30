<#
.SYNOPSIS
    Normalizes orchestrator NewUser properties to Microsoft Graph camelCase body fields.

.DESCRIPTION
    Accepts camelCase or PascalCase keys for allowed user creation fields. Rejects
    unknown keys and password material from the caller hashtable.

.PARAMETER Properties
    Caller property hashtable (no password).

.OUTPUTS
    System.Collections.Hashtable with camelCase keys for New-MgUser.
#>

function ConvertTo-ProvisioningGraphNewUserBody {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Properties
    )

    $allowed = @(
        'userPrincipalName', 'mailNickname', 'givenName', 'surname',
        'displayName', 'department', 'accountEnabled', 'usageLocation'
    )

    $normalized = @{}
    foreach ($entry in $Properties.GetEnumerator()) {
        $key = [string] $entry.Key
        if ($key -match '(?i)password') {
            throw [System.InvalidOperationException]::new(
                'Graph validation failed: password must not be supplied to NewUser.')
        }

        $camelKey = $key.Substring(0, 1).ToLowerInvariant() + $key.Substring(1)
        if ($allowed -notcontains $camelKey) {
            throw [System.InvalidOperationException]::new(
                "Graph validation failed: property '$key' is not allowed for NewUser.")
        }

        $normalized[$camelKey] = $entry.Value
    }

    if (-not $normalized.ContainsKey('accountEnabled')) {
        $normalized['accountEnabled'] = $true
    }

    return $normalized
}
