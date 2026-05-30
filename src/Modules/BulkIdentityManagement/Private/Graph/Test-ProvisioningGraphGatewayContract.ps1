<#
.SYNOPSIS
    Validates a Graph gateway hashtable implements the Task 7 ScriptBlock contract.

.PARAMETER GraphGateway
    Hashtable expected to expose six ScriptBlock gateway operations.

.NOTES
    Private function; consumed by Invoke-ProvisioningOrchestrator before batch processing.
#>

function Test-ProvisioningGraphGatewayContract {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $GraphGateway
    )

    $requiredKeys = @(
        'TestUpnExists', 'NewUser', 'UpdateUser',
        'GetGroupById', 'TestGroupMembership', 'AddGroupMember'
    )

    foreach ($key in $requiredKeys) {
        if (-not $GraphGateway.ContainsKey($key)) {
            throw [System.ArgumentException]::new(
                "Graph gateway is missing required operation '$key'.",
                'GraphGateway')
        }

        if ($GraphGateway[$key] -isnot [scriptblock]) {
            throw [System.ArgumentException]::new(
                "Graph gateway operation '$key' must be a ScriptBlock.",
                'GraphGateway')
        }
    }
}
