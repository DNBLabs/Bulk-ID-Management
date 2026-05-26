<#
.SYNOPSIS
    Constructs a Graph gateway hashtable stub for testing and contract documentation.

.DESCRIPTION
    Returns a hashtable with six ScriptBlock entries representing the minimal Graph
    operations the orchestrator requires. Each entry throws 'not implemented' until
    Task 8 replaces placeholders with in-memory fake logic. Task 10 provides a
    separate New-ProvisioningGraphGateway builder backed by real Microsoft.Graph calls.

    Gateway contract (v1):
      TestUpnExists       - UPN string -> user Object ID string if found, $null if not
      NewUser             - hashtable of user fields (no password) -> created Object ID;
                            gateway generates random password + forceChangePasswordNextSignIn
      UpdateUser          - Object ID + hashtable of patchable fields -> void
      GetGroupById        - group Object ID string -> group info or throw
      TestGroupMembership - user Object ID + group Object ID -> bool
      AddGroupMember      - user Object ID + group Object ID -> void (idempotent)

    Errors: operations throw on failure; orchestrator catches per row.
    No Microsoft.Graph calls in this file. See CONTEXT.md Graph gateway contract.

.OUTPUTS
    System.Collections.Hashtable

.NOTES
    Private function; not exported. Consumed by the orchestrator (Task 12) and Pester.
#>

function New-FakeProvisioningGraphGateway {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Creates an in-memory hashtable stub; no system state changes.')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return @{
        TestUpnExists       = { throw [System.NotImplementedException]::new('TestUpnExists is not implemented.') }
        NewUser             = { throw [System.NotImplementedException]::new('NewUser is not implemented.') }
        UpdateUser          = { throw [System.NotImplementedException]::new('UpdateUser is not implemented.') }
        GetGroupById        = { throw [System.NotImplementedException]::new('GetGroupById is not implemented.') }
        TestGroupMembership = { throw [System.NotImplementedException]::new('TestGroupMembership is not implemented.') }
        AddGroupMember      = { throw [System.NotImplementedException]::new('AddGroupMember is not implemented.') }
    }
}
