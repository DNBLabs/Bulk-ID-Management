<#
.SYNOPSIS
    Executes a Graph script block with bounded transient retry policy.

.DESCRIPTION
    Retries on HTTP 429 and selected 5xx responses with exponential backoff, honors
    Retry-After when present, and enforces a cumulative wait cap. Non-retryable errors
    and exhausted retries throw InvalidOperationException with a Graph operation prefix.

.PARAMETER OperationName
    Logical gateway operation name for error messages (e.g. TestUpnExists).

.PARAMETER Command
    Script block invoking Microsoft.Graph v1.0 cmdlets.

.PARAMETER MaxAttempts
    Maximum invocation attempts (default 5).

.PARAMETER BaseDelaySeconds
    Base delay for exponential backoff (default 2 seconds).

.PARAMETER CumulativeWaitCapSeconds
    Maximum total sleep seconds per logical call (default 90).

.PARAMETER DelayScript
    Optional script block invoked as & $DelayScript $secondsToWait (for tests).

.OUTPUTS
    Whatever the Command script block returns.

.NOTES
    Retry defaults are fixed for v1 per CONTEXT.md (not configurable at apply time).
#>

$script:ProvisioningGraphMaxAttempts = 5
$script:ProvisioningGraphBaseDelaySeconds = 2
$script:ProvisioningGraphCumulativeWaitCapSeconds = 90
$script:ProvisioningGraphRetryableStatusCodes = @(429, 500, 502, 503, 504)

function Invoke-ProvisioningGraphCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $OperationName,

        [Parameter(Mandatory)]
        [scriptblock] $Command,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $MaxAttempts = $script:ProvisioningGraphMaxAttempts,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $BaseDelaySeconds = $script:ProvisioningGraphBaseDelaySeconds,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $CumulativeWaitCapSeconds = $script:ProvisioningGraphCumulativeWaitCapSeconds,

        [Parameter()]
        [scriptblock] $DelayScript
    )

    if ($null -eq $DelayScript) {
        $DelayScript = {
            param([int] $SecondsToWait)
            Start-Sleep -Seconds $SecondsToWait
        }
    }

    $attempt = 0
    $cumulativeWaitSeconds = 0

    while ($true) {
        $attempt++
        try {
            return & $Command
        }
        catch {
            $metadata = Get-ProvisioningGraphErrorMetadata -ErrorRecord $_
            $statusCode = $metadata.StatusCode
            $isRetryable = $null -ne $statusCode -and
                $statusCode -in $script:ProvisioningGraphRetryableStatusCodes

            if (-not $isRetryable -or $attempt -ge $MaxAttempts) {
                $sanitized = Get-SanitizedProvisioningFailureReason -Message $_.Exception.Message
                throw [System.InvalidOperationException]::new(
                    "Graph $OperationName failed: $sanitized",
                    $_.Exception)
            }

            $exponentialDelay = $BaseDelaySeconds * [math]::Pow(2, $attempt - 1)
            $retryAfter = $metadata.RetryAfterSeconds
            $delaySeconds = [int] [math]::Ceiling([math]::Max($exponentialDelay, $retryAfter))

            if (($cumulativeWaitSeconds + $delaySeconds) -gt $CumulativeWaitCapSeconds) {
                $sanitized = Get-SanitizedProvisioningFailureReason -Message $_.Exception.Message
                throw [System.InvalidOperationException]::new(
                    "Graph $OperationName failed: transient retry cumulative wait cap exceeded.",
                    $_.Exception)
            }

            & $DelayScript $delaySeconds
            $cumulativeWaitSeconds += $delaySeconds
        }
    }
}
