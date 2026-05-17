<#
.SYNOPSIS
    Normalizes a MailNickname base or CSV override per CONTEXT.md.

.DESCRIPTION
    Lowercases, maps eszett to ss, strips diacritics via Unicode Form D, removes spaces,
    retains only [a-z0-9.-], collapses repeated dots and hyphens, trims edge punctuation,
    and validates the result contains at least one letter.

.PARAMETER NicknameInput
    Dot-joined mapped names or CSV MailNickname override before normalization.

.PARAMETER SourceLineNumber
    1-based physical file line for error messages.

.OUTPUTS
    System.String normalized MailNickname.

.NOTES
    Throws System.InvalidOperationException when validation fails.
#>
function Get-NormalizedProvisioningMailNickname {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $NicknameInput,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $SourceLineNumber
    )

    if ($null -eq $MaxProvisioningMailNicknameInputLength) {
        throw [System.InvalidOperationException]::new(
            'Provisioning identity constants are not available in the current scope.'
        )
    }

    if ($NicknameInput.Length -gt $MaxProvisioningMailNicknameInputLength) {
        throw [System.InvalidOperationException]::new(
            "Could not derive a valid MailNickname for provisioning row on physical line $SourceLineNumber."
        )
    }

    $normalized = $NicknameInput.ToLowerInvariant()
    $normalized = $normalized.Replace([string][char]0x00DF, 'ss')

    $formD = $normalized.Normalize([System.Text.NormalizationForm]::FormD)
    $withoutMarks = [System.Text.StringBuilder]::new()
    foreach ($character in $formD.ToCharArray()) {
        $category = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($character)
        if ($category -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void] $withoutMarks.Append($character)
        }
    }

    $normalized = $withoutMarks.ToString()
    $normalized = $normalized -replace '\s+', ''

    $safeCharacters = [System.Text.StringBuilder]::new()
    foreach ($character in $normalized.ToCharArray()) {
        if ($character -match '[a-z0-9.\-]') {
            [void] $safeCharacters.Append($character)
        }
    }

    $normalized = $safeCharacters.ToString()
    $normalized = [System.Text.RegularExpressions.Regex]::Replace($normalized, '\.+', '.')
    $normalized = [System.Text.RegularExpressions.Regex]::Replace($normalized, '-+', '-')
    $normalized = $normalized.Trim('.', '-')

    if ($normalized.Length -eq 0 -or $normalized -notmatch '[a-z]') {
        throw [System.InvalidOperationException]::new(
            "Could not derive a valid MailNickname for provisioning row on physical line $SourceLineNumber."
        )
    }

    return $normalized
}
