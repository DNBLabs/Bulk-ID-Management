<#
.SYNOPSIS
    Normalizes UpdateUser patch properties to allowed Graph fields only.

.PARAMETER Properties
    Patch hashtable from orchestrator.

.OUTPUTS
    System.Collections.Hashtable with camelCase keys: department, givenName, surname, displayName.
#>

function ConvertTo-ProvisioningGraphPatchBody {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Properties
    )

    $allowed = @('department', 'givenName', 'surname', 'displayName')
    $normalized = @{}

    foreach ($entry in $Properties.GetEnumerator()) {
        $key = [string] $entry.Key
        $camelKey = $key.Substring(0, 1).ToLowerInvariant() + $key.Substring(1)
        if ($allowed -notcontains $camelKey) {
            throw [System.InvalidOperationException]::new(
                "Graph validation failed: property '$key' is not allowed for UpdateUser.")
        }

        $normalized[$camelKey] = $entry.Value
    }

    return $normalized
}
