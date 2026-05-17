<#
.SYNOPSIS
    Imports a provisioning CSV file and outputs validated provisioning row objects.

.DESCRIPTION
    Reads the file at Path as UTF-8, parses comma-separated logical records, validates the
    header row, and materializes data rows per CONTEXT.md Provisioning CSV format.

    Validation order: encoding read, CSV structure parse, header validation, row
    materialization. Any failure throws a terminating error and emits no pipeline output.

.PARAMETER Path
    Filesystem path to the provisioning CSV file.

.OUTPUTS
    PSCustomObject provisioning rows with SourceLineNumber, required identity fields,
    and optional properties only when present in the header and non-empty in the row.

.NOTES
    Normative contract: CONTEXT.md at repository root (Provisioning CSV format).
    Does not call Microsoft Graph.
#>
function Import-ProvisioningCsv {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $physicalLines = Read-ProvisioningCsvUtf8 -Path $Path
    if ($null -eq $physicalLines) {
        $physicalLines = [string[]]@()
    }

    $logicalRecords = Get-ProvisioningCsvLogicalRecords -PhysicalLines $physicalLines

    if ($logicalRecords.Count -eq 0) {
        throw [System.InvalidOperationException]::new(
            'Provisioning CSV file does not contain a header row.'
        )
    }

    $headerRecord = $logicalRecords[0]
    $columnMap = Get-ProvisioningCsvHeaderColumnMap -HeaderFields $headerRecord.Fields -HeaderStartLineNumber $headerRecord.StartLineNumber

    $dataLogicalRecords = @()
    if ($logicalRecords.Count -gt 1) {
        $dataLogicalRecords = $logicalRecords[1..($logicalRecords.Count - 1)]
    }

    $materializedRows = Get-ProvisioningCsvMaterializedRows -DataLogicalRecords $dataLogicalRecords -HeaderColumnMap $columnMap

    Write-Output -InputObject $materializedRows
}
