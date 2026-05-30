<#
.SYNOPSIS
    Constructs a fake Graph gateway backed by in-memory state dictionaries.

.DESCRIPTION
    Returns a hashtable with six ScriptBlock entries implementing the Graph
    gateway contract using caller-supplied state. ScriptBlocks delegate to
    Invoke-FakeProvisioningGraphGateway* via module-scoped function ScriptBlocks
    and close over State with GetNewClosure.

    See CONTEXT.md and Invoke-FakeProvisioningGraphGatewayOperations.ps1.

.PARAMETER State
    Hashtable with Users, UpnIndex, Groups, Members sub-dictionaries.
    When omitted, empty defaults are created internally.

.OUTPUTS
    System.Collections.Hashtable

.NOTES
    Private function; not exported. Consumed by the orchestrator (Task 12) and Pester.
#>

function New-FakeProvisioningGraphGateway {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Constructs an in-memory test double; no external state changes.')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [hashtable] $State
    )

    if (-not $State) {
        $State = @{
            Users    = @{}
            UpnIndex = @{}
            Groups   = @{}
            Members  = @{}
        }
    }

    $testUpnExists = ${function:Invoke-FakeProvisioningGraphGatewayTestUpnExists}
    $newUser = ${function:Invoke-FakeProvisioningGraphGatewayNewUser}
    $updateUser = ${function:Invoke-FakeProvisioningGraphGatewayUpdateUser}
    $getGroupById = ${function:Invoke-FakeProvisioningGraphGatewayGetGroupById}
    $testGroupMembership = ${function:Invoke-FakeProvisioningGraphGatewayTestGroupMembership}
    $addGroupMember = ${function:Invoke-FakeProvisioningGraphGatewayAddGroupMember}

    return @{
        TestUpnExists = {
            param([string] $Upn)
            & $testUpnExists -State $State -Upn $Upn
        }.GetNewClosure()

        NewUser = {
            param([hashtable] $Properties)
            & $newUser -State $State -Properties $Properties
        }.GetNewClosure()

        UpdateUser = {
            param([string] $UserId, [hashtable] $Properties)
            & $updateUser -State $State -UserId $UserId -Properties $Properties
        }.GetNewClosure()

        GetGroupById = {
            param([string] $GroupId)
            & $getGroupById -State $State -GroupId $GroupId
        }.GetNewClosure()

        TestGroupMembership = {
            param([string] $UserId, [string] $GroupId)
            & $testGroupMembership -State $State -UserId $UserId -GroupId $GroupId
        }.GetNewClosure()

        AddGroupMember = {
            param([string] $UserId, [string] $GroupId)
            & $addGroupMember -State $State -UserId $UserId -GroupId $GroupId
        }.GetNewClosure()
    }
}
