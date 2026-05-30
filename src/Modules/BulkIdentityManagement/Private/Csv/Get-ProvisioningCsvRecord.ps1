<#
.SYNOPSIS
    Parses provisioning CSV physical lines into logical records with field values.

.DESCRIPTION
    Comma-separated values only (no delimiter sniffing). Supports RFC-style quoted fields,
    including commas and physical newlines inside quotes and escaped double quotes ("").
    Each logical record includes StartLineNumber (1-based physical line where the record begins)
    and Fields (ordered string values). Malformed quoting throws a terminating error.

.PARAMETER PhysicalLines
    Physical lines from Read-ProvisioningCsvUtf8 in file order.

.OUTPUTS
    PSCustomObject[] with StartLineNumber (int) and Fields (string[]).

.NOTES
    Does not validate headers or required columns; see later tasks.
    Per-record field count is capped to limit comma-bomb parsing within the file size bound.
    An empty physical line yields one logical record with a single empty field; row materialization
    skips all-whitespace data rows in a later task.
#>

$MaxProvisioningCsvFieldsPerRecord = 256

function Get-ProvisioningCsvLogicalRecords {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns',
        '',
        Justification = 'Cmdlet returns multiple logical CSV records from physical lines.')]
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]] $PhysicalLines
    )

    if ($null -eq $PhysicalLines -or $PhysicalLines.Count -eq 0) {
        return @()
    }

    $records = [System.Collections.Generic.List[object]]::new()
    $fields = [System.Collections.Generic.List[string]]::new()
    $fieldChars = [System.Collections.Generic.List[char]]::new()
    $inQuotedField = $false
    $recordStartLine = 1
    $lineIndex = 0

    $ensureFieldCountAllowed = {
        if ($fields.Count -ge $MaxProvisioningCsvFieldsPerRecord) {
            throw [System.InvalidOperationException]::new(
                "Provisioning CSV record exceeds the maximum of $MaxProvisioningCsvFieldsPerRecord fields near physical line $recordStartLine."
            )
        }
    }

    $commitField = {
        & $ensureFieldCountAllowed
        $fields.Add(-join $fieldChars) | Out-Null
        [void] $fieldChars.Clear()
    }

    $commitRecord = {
        if ($fields.Count -eq 0) {
            return
        }

        $records.Add([PSCustomObject]@{
                StartLineNumber = $recordStartLine
                Fields          = [string[]] $fields.ToArray()
            }) | Out-Null
        [void] $fields.Clear()
    }

    $throwMalformed = {
        param([int] $StartLine)
        throw [System.InvalidOperationException]::new(
            "Malformed provisioning CSV quoting near physical line $StartLine."
        )
    }

    while ($lineIndex -lt $PhysicalLines.Count) {
        $line = $PhysicalLines[$lineIndex]
        if ($null -eq $line) {
            $line = ''
        }

        if ($fields.Count -eq 0 -and $fieldChars.Count -eq 0 -and -not $inQuotedField) {
            $recordStartLine = $lineIndex + 1
        }

        $charIndex = 0
        while ($charIndex -lt $line.Length) {
            $character = $line[$charIndex]

            if ($inQuotedField) {
                if ($character -eq '"') {
                    if ($charIndex + 1 -lt $line.Length -and $line[$charIndex + 1] -eq '"') {
                        $fieldChars.Add('"') | Out-Null
                        $charIndex += 2
                        continue
                    }

                    $inQuotedField = $false
                    $charIndex++

                    if ($charIndex -lt $line.Length) {
                        $nextCharacter = $line[$charIndex]
                        if ($nextCharacter -ne ',') {
                            & $throwMalformed $recordStartLine
                        }
                    }

                    continue
                }

                $fieldChars.Add($character) | Out-Null
                $charIndex++
                continue
            }

            if ($character -eq '"') {
                $inQuotedField = $true
                $charIndex++
                continue
            }

            if ($character -eq ',') {
                & $commitField
                $charIndex++
                continue
            }

            $fieldChars.Add($character) | Out-Null
            $charIndex++
        }

        if ($inQuotedField) {
            $fieldChars.Add("`n") | Out-Null
            $lineIndex++
            continue
        }

        & $commitField
        & $commitRecord
        $lineIndex++
    }

    if ($inQuotedField) {
        & $throwMalformed $recordStartLine
    }

    return $records.ToArray()
}
