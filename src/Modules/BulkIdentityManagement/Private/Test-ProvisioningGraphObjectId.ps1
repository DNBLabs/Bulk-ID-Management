<#
.SYNOPSIS
    Validates that a value is a GUID suitable for Graph Object ID parameters.

.PARAMETER Id
    Candidate Object ID string.

.PARAMETER ParameterName
    Name used in validation error messages.

.OUTPUTS
    None. Throws InvalidOperationException when invalid.
#>

function Test-ProvisioningGraphObjectId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Id,

        [Parameter(Mandatory)]
        [string] $ParameterName
    )

    $parsed = [guid]::Empty
    if (-not [guid]::TryParse($Id, [ref]$parsed)) {
        throw [System.InvalidOperationException]::new(
            "Graph validation failed: '$ParameterName' is not a valid Object ID GUID.")
    }
}
