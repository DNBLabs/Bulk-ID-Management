<#
.SYNOPSIS
    Materializes provisioning row objects from logical CSV data records.

.DESCRIPTION
    For each data logical record after the header, skips rows whose fields are all
    empty or whitespace after trim. Otherwise validates required canonical cells are
    non-empty after trim and builds a PSCustomObject with SourceLineNumber, required
    properties, and optional properties only when the header column exists and the
    cell is non-empty after trim. Throws when no rows are materialized.

.PARAMETER DataLogicalRecords
    Logical CSV records excluding the header row.

.PARAMETER HeaderColumnMap
    Canonical header name to zero-based field index map from Get-ProvisioningCsvHeaderColumnMap.

.OUTPUTS
    PSCustomObject[] provisioning rows per CONTEXT.md.

.NOTES
    Requires header name constants from ProvisioningCsv.Constants.ps1 in scope.
    Data record count is capped to limit unbounded materialization when invoked directly.
#>

$MaxProvisioningCsvDataRecordCount = 65535

function Get-ProvisioningCsvMaterializedRows {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns',
        '',
        Justification = 'Cmdlet returns multiple materialized provisioning rows from CSV data records.')]
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $DataLogicalRecords,

        [Parameter(Mandatory)]
        [hashtable] $HeaderColumnMap
    )

    if ($null -eq $RequiredProvisioningCsvHeaderNames -or $null -eq $OptionalProvisioningCsvHeaderNames) {
        throw [System.InvalidOperationException]::new(
            'Provisioning CSV header constants are not available in the current scope.'
        )
    }

    if ($DataLogicalRecords.Count -gt $MaxProvisioningCsvDataRecordCount) {
        throw [System.InvalidOperationException]::new(
            "Provisioning CSV data exceeds the maximum of $MaxProvisioningCsvDataRecordCount logical records."
        )
    }

    foreach ($requiredHeaderName in $RequiredProvisioningCsvHeaderNames) {
        if (-not $HeaderColumnMap.ContainsKey($requiredHeaderName)) {
            throw [System.InvalidOperationException]::new(
                "Provisioning CSV header column map is missing required column '$requiredHeaderName'."
            )
        }
    }

    $materializedRows = [System.Collections.Generic.List[object]]::new()

    foreach ($logicalRecord in $DataLogicalRecords) {
        if ($null -eq $logicalRecord) {
            continue
        }

        $fieldValues = $logicalRecord.Fields
        if ($null -eq $fieldValues) {
            $fieldValues = @()
        }

        $hasNonWhitespaceField = $false
        foreach ($fieldValue in $fieldValues) {
            $cellText = if ($null -eq $fieldValue) { '' } else { $fieldValue }
            if ($cellText.Trim().Length -gt 0) {
                $hasNonWhitespaceField = $true
                break
            }
        }

        if (-not $hasNonWhitespaceField) {
            continue
        }

        $sourceLineNumber = $logicalRecord.StartLineNumber
        if ($sourceLineNumber -lt 1) {
            throw [System.InvalidOperationException]::new(
                "Provisioning CSV data record has an invalid source line number on physical line $sourceLineNumber."
            )
        }

        $rowProperties = [ordered]@{
            SourceLineNumber = $sourceLineNumber
        }

        foreach ($requiredHeaderName in $RequiredProvisioningCsvHeaderNames) {
            $fieldIndex = $HeaderColumnMap[$requiredHeaderName]
            $trimmedValue = Get-TrimmedProvisioningCsvFieldValue -FieldValues $fieldValues -FieldIndex $fieldIndex
            if ($trimmedValue.Length -eq 0) {
                throw [System.InvalidOperationException]::new(
                    "Required provisioning CSV field '$requiredHeaderName' is empty on physical line $sourceLineNumber."
                )
            }

            $rowProperties[$requiredHeaderName] = $trimmedValue
        }

        foreach ($optionalHeaderName in $OptionalProvisioningCsvHeaderNames) {
            if (-not $HeaderColumnMap.ContainsKey($optionalHeaderName)) {
                continue
            }

            $trimmedOptionalValue = Get-TrimmedProvisioningCsvFieldValue -FieldValues $fieldValues -FieldIndex $HeaderColumnMap[$optionalHeaderName]
            if ($trimmedOptionalValue.Length -gt 0) {
                $rowProperties[$optionalHeaderName] = $trimmedOptionalValue
            }
        }

        $materializedRows.Add([PSCustomObject] $rowProperties) | Out-Null
    }

    if ($materializedRows.Count -eq 0) {
        throw [System.InvalidOperationException]::new('The CSV file contains no provisioning rows.')
    }

    return $materializedRows.ToArray()
}

function Get-TrimmedProvisioningCsvFieldValue {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string[]] $FieldValues,

        [Parameter(Mandatory)]
        [int] $FieldIndex
    )

    if ($FieldIndex -lt 0 -or $FieldIndex -ge $FieldValues.Count) {
        return ''
    }

    $fieldValue = $FieldValues[$FieldIndex]
    if ($null -eq $fieldValue) {
        return ''
    }

    return $fieldValue.Trim()
}
