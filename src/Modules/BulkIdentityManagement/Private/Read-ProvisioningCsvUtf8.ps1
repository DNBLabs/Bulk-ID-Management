<#
.SYNOPSIS
    Reads a provisioning CSV file as strict UTF-8 physical lines.

.DESCRIPTION
    Reads the file at Path as UTF-8 only. An optional UTF-8 BOM is stripped before decoding.
    Invalid byte sequences throw a terminating error. Returns one string per physical line
    (line terminators removed) for downstream CSV record parsing.

.PARAMETER Path
    Filesystem path to the CSV file.

.OUTPUTS
    [string[]] Physical lines in file order.

.NOTES
    Does not parse CSV fields; see Get-ProvisioningCsvRecord in a later task.
    Maximum file size is 10 MB to limit memory use on untrusted paths.
#>

$MaxProvisioningCsvFileBytes = 10MB

function Read-ProvisioningCsvUtf8 {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new("Provisioning CSV file not found: $Path")
    }

    $resolvedPath = (Resolve-Path -LiteralPath $Path).ProviderPath
    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new("Provisioning CSV file not found: $Path")
    }

    $fileInfo = [System.IO.FileInfo]::new($resolvedPath)
    if ($fileInfo.Length -gt $MaxProvisioningCsvFileBytes) {
        throw [System.InvalidOperationException]::new(
            "Provisioning CSV file is too large (maximum size is $MaxProvisioningCsvFileBytes bytes).")
    }

    $bytes = [System.IO.File]::ReadAllBytes($resolvedPath)

    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        if ($bytes.Length -eq 3) {
            $bytes = [byte[]]::new(0)
        }
        else {
            $bytes = $bytes[3..($bytes.Length - 1)]
        }
    }

    $utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)
    try {
        $text = $utf8Strict.GetString($bytes)
    }
    catch [System.Text.DecoderFallbackException] {
        throw [System.InvalidOperationException]::new('Provisioning CSV file is not valid UTF-8.')
    }

    if ([string]::IsNullOrEmpty($text)) {
        return @()
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $reader = [System.IO.StringReader]::new($text)
    try {
        while ($null -ne ($line = $reader.ReadLine())) {
            $lines.Add($line)
        }
    }
    finally {
        $reader.Dispose()
    }

    return [string[]]$lines.ToArray()
}
