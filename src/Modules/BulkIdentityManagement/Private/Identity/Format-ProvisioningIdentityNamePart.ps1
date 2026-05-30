<#
.SYNOPSIS
    Trims and collapses internal whitespace in a provisioning identity name part.

.DESCRIPTION
    Removes leading and trailing whitespace and replaces runs of whitespace characters
    with a single ASCII space. Returns an empty string when the input is null, empty,
    or whitespace-only.

.PARAMETER NamePart
    Raw name text from a provisioning row or override column.

.OUTPUTS
    System.String trimmed and collapsed, or empty when input has no non-whitespace content.

.NOTES
    Used by name mapping and MailNickname base construction per CONTEXT.md.
#>
function Format-ProvisioningIdentityNamePart {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $NamePart
    )

    if ([string]::IsNullOrWhiteSpace($NamePart)) {
        return ''
    }

    $trimmed = $NamePart.Trim()
    return [System.Text.RegularExpressions.Regex]::Replace($trimmed, '\s+', ' ')
}
