<#
.SYNOPSIS
    Constructs the real Microsoft Graph gateway for bulk provisioning operations.

.DESCRIPTION
    Returns a hashtable with six ScriptBlock entries implementing the Task 7 gateway
    contract against Microsoft.Graph v1.0 cmdlets. Requires Connect-ProvisioningGraph
    to have established a session before calling this builder.

    Selects Graph API profile v1.0 once at construction. Each operation delegates to
    module-scoped gateway operation functions via function ScriptBlocks.

    See CONTEXT.md and PRD-Task-10-Real-Graph-Gateway.md.

.OUTPUTS
    System.Collections.Hashtable

.NOTES
    Private function; not exported. Consumed by the orchestrator (Task 12) after auth.
#>

function New-ProvisioningGraphGateway {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Returns gateway ScriptBlocks; Graph mutations occur when operations are invoked.')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    try {
        Select-MgProfile -Name 'v1.0' -ErrorAction Stop
    }
    catch {
        throw [System.InvalidOperationException]::new(
            "Failed to select Microsoft Graph API profile 'v1.0'. Inspect InnerException for SDK details.",
            $_.Exception)
    }

    return @{
        TestUpnExists       = ${function:Invoke-ProvisioningGraphGatewayTestUpnExists}
        NewUser             = ${function:Invoke-ProvisioningGraphGatewayNewUser}
        UpdateUser          = ${function:Invoke-ProvisioningGraphGatewayUpdateUser}
        GetGroupById        = ${function:Invoke-ProvisioningGraphGatewayGetGroupById}
        TestGroupMembership = ${function:Invoke-ProvisioningGraphGatewayTestGroupMembership}
        AddGroupMember      = ${function:Invoke-ProvisioningGraphGatewayAddGroupMember}
    }
}
