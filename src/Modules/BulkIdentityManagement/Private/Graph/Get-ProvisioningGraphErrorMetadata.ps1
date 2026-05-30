<#
.SYNOPSIS
    Extracts HTTP status code and Retry-After seconds from a Graph-related error.

.DESCRIPTION
    Supports test exceptions via Exception.Data keys ProvisioningGraphStatusCode and
    ProvisioningGraphRetryAfter, plus common .NET HTTP response shapes from SDK/cmdlets.

.PARAMETER ErrorRecord
    The caught error record from a Graph cmdlet invocation.

.OUTPUTS
    System.Collections.Hashtable with StatusCode (nullable int) and RetryAfterSeconds (int, 0 when absent).
#>

function Get-ProvisioningGraphErrorMetadata {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )

    $statusCode = $null
    $retryAfterSeconds = 0
    $exception = $ErrorRecord.Exception

    if ($null -ne $exception.Data -and $exception.Data.Contains('ProvisioningGraphStatusCode')) {
        $statusCode = [int] $exception.Data['ProvisioningGraphStatusCode']
    }

    if ($null -ne $exception.Data -and $exception.Data.Contains('ProvisioningGraphRetryAfter')) {
        $retryAfterSeconds = [int] $exception.Data['ProvisioningGraphRetryAfter']
    }

    if ($null -eq $statusCode) {
        $response = $null
        if ($exception.PSObject.Properties.Match('Response').Count -gt 0) {
            $response = $exception.Response
        }
        elseif ($null -ne $exception.InnerException -and
            $exception.InnerException.PSObject.Properties.Match('Response').Count -gt 0) {
            $response = $exception.InnerException.Response
        }

        if ($null -ne $response) {
            if ($response.PSObject.Properties.Match('StatusCode').Count -gt 0) {
                $rawStatus = $response.StatusCode
                if ($rawStatus -is [System.Net.HttpStatusCode]) {
                    $statusCode = [int] $rawStatus
                }
                else {
                    $statusCode = [int] $rawStatus
                }
            }

            if ($retryAfterSeconds -le 0 -and $response.PSObject.Properties.Match('Headers').Count -gt 0) {
                $headers = $response.Headers
                if ($null -ne $headers -and $headers.Contains('Retry-After')) {
                    $headerValue = $headers['Retry-After']
                    if ($headerValue -is [System.Array]) {
                        $headerValue = $headerValue[0]
                    }
                    [void][int]::TryParse([string] $headerValue, [ref]$retryAfterSeconds)
                }
            }
        }
    }

    return @{
        StatusCode          = $statusCode
        RetryAfterSeconds   = $retryAfterSeconds
    }
}
