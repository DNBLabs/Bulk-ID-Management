<#
.SYNOPSIS
    Validates provisioning CSV header rows and builds a canonical column index map.

.DESCRIPTION
    Trims header cells, rejects duplicate header names after trim, verifies all required
    canonical columns are present with case-sensitive names, and maps each recognized
    canonical header to its zero-based field index. Unknown header columns are ignored.

.PARAMETER HeaderFields
    Field values from the first logical CSV record (header row).

.PARAMETER HeaderStartLineNumber
    1-based physical line number where the header record begins (for error messages).

.OUTPUTS
    Hashtable mapping canonical column names to zero-based field indexes.

.NOTES
    Requires $RequiredProvisioningCsvHeaderNames and $OptionalProvisioningCsvHeaderNames
    from ProvisioningCsv.Constants.ps1 in scope. Does not process data rows.
    Header field count is capped to match the logical CSV record parser limit.
#>

$MaxProvisioningCsvHeaderFieldCount = 256

function Get-ProvisioningCsvHeaderColumnMap {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string[]] $HeaderFields,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $HeaderStartLineNumber = 1
    )

    if ($null -eq $RequiredProvisioningCsvHeaderNames -or $null -eq $OptionalProvisioningCsvHeaderNames) {
        throw [System.InvalidOperationException]::new(
            'Provisioning CSV header constants are not available in the current scope.'
        )
    }

    if ($HeaderFields.Count -gt $MaxProvisioningCsvHeaderFieldCount) {
        throw [System.InvalidOperationException]::new(
            "Provisioning CSV header row exceeds the maximum of $MaxProvisioningCsvHeaderFieldCount fields (physical line $HeaderStartLineNumber)."
        )
    }

    $canonicalHeaderNames = @(
        $RequiredProvisioningCsvHeaderNames
        $OptionalProvisioningCsvHeaderNames
    )
    $canonicalNameSet = [System.Collections.Generic.HashSet[string]]::new(
        [string[]] $canonicalHeaderNames,
        [System.StringComparer]::Ordinal
    )

    $columnMap = @{}
    $seenTrimmedHeaderNames = @{}

    for ($fieldIndex = 0; $fieldIndex -lt $HeaderFields.Count; $fieldIndex++) {
        $headerCell = $HeaderFields[$fieldIndex]
        if ($null -eq $headerCell) {
            $headerCell = ''
        }

        $trimmedHeaderName = $headerCell.Trim()
        if ($seenTrimmedHeaderNames.ContainsKey($trimmedHeaderName)) {
            throw [System.InvalidOperationException]::new(
                "Duplicate provisioning CSV header '$trimmedHeaderName' on header row (physical line $HeaderStartLineNumber)."
            )
        }

        $seenTrimmedHeaderNames[$trimmedHeaderName] = $true

        if ($canonicalNameSet.Contains($trimmedHeaderName)) {
            $columnMap[$trimmedHeaderName] = $fieldIndex
        }
    }

    foreach ($requiredHeaderName in $RequiredProvisioningCsvHeaderNames) {
        if (-not $columnMap.ContainsKey($requiredHeaderName)) {
            throw [System.InvalidOperationException]::new(
                "Missing required provisioning CSV header '$requiredHeaderName' on header row (physical line $HeaderStartLineNumber)."
            )
        }
    }

    return $columnMap
}
