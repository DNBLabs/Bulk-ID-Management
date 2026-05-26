<#
.SYNOPSIS
    Constructs a fake Graph gateway backed by in-memory state dictionaries.

.DESCRIPTION
    Returns a hashtable with six ScriptBlock entries implementing the Graph
    gateway contract using caller-supplied state. Each ScriptBlock closes over
    the $State reference so tests can pre-seed data and inspect mutations.

    Gateway contract (v1):
      TestUpnExists       - UPN string -> user Object ID string if found, $null if not
      NewUser             - hashtable of user fields (no password) -> created Object ID
      UpdateUser          - Object ID + hashtable of patchable fields -> void
      GetGroupById        - group Object ID string -> group info or throw
      TestGroupMembership - user Object ID + group Object ID -> bool
      AddGroupMember      - user Object ID + group Object ID -> void (idempotent)

    State shape (four sub-dictionaries):
      Users    - keyed by Object ID -> user property hashtable with 'id'
      UpnIndex - keyed by lowercase UPN -> Object ID (lookup index)
      Groups   - keyed by group Object ID -> group info hashtable
      Members  - keyed by group Object ID -> HashSet[string] of user Object IDs

    No Microsoft.Graph calls. No password material stored. See CONTEXT.md.

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

    return @{
        TestUpnExists = {
            param([string] $Upn)
            $key = $Upn.ToLowerInvariant()
            if ($State.UpnIndex.ContainsKey($key)) {
                return $State.UpnIndex[$key]
            }
            return $null
        }.GetNewClosure()

        NewUser = {
            param([hashtable] $Properties)
            $upnKey = $Properties['userPrincipalName']
            if (-not $upnKey) { $upnKey = $Properties['UserPrincipalName'] }
            if ($upnKey) {
                $lowered = $upnKey.ToLowerInvariant()
                if ($State.UpnIndex.ContainsKey($lowered)) {
                    throw [System.InvalidOperationException]::new(
                        "User with UPN '$upnKey' already exists.")
                }
            }
            $objectId = [guid]::NewGuid().ToString()
            $record = $Properties.Clone()
            $record['id'] = $objectId
            $State.Users[$objectId] = $record
            if ($upnKey) {
                $State.UpnIndex[$upnKey.ToLowerInvariant()] = $objectId
            }
            return $objectId
        }.GetNewClosure()

        UpdateUser = {
            param([string] $UserId, [hashtable] $Properties)
            if (-not $State.Users.ContainsKey($UserId)) {
                throw [System.InvalidOperationException]::new(
                    "User with Object ID '$UserId' not found.")
            }
            $existing = $State.Users[$UserId]
            foreach ($patchKey in $Properties.Keys) {
                $existing[$patchKey] = $Properties[$patchKey]
            }
        }.GetNewClosure()

        GetGroupById = {
            param([string] $GroupId)
            if (-not $State.Groups.ContainsKey($GroupId)) {
                throw [System.InvalidOperationException]::new(
                    "Group with Object ID '$GroupId' not found.")
            }
            return $State.Groups[$GroupId]
        }.GetNewClosure()

        TestGroupMembership = {
            param([string] $UserId, [string] $GroupId)
            if (-not $State.Members.ContainsKey($GroupId)) {
                $State.Members[$GroupId] = [System.Collections.Generic.HashSet[string]]::new()
            }
            return $State.Members[$GroupId].Contains($UserId)
        }.GetNewClosure()

        AddGroupMember = {
            param([string] $UserId, [string] $GroupId)
            if (-not $State.Groups.ContainsKey($GroupId)) {
                throw [System.InvalidOperationException]::new(
                    "Group with Object ID '$GroupId' not found.")
            }
            if (-not $State.Members.ContainsKey($GroupId)) {
                $State.Members[$GroupId] = [System.Collections.Generic.HashSet[string]]::new()
            }
            [void] $State.Members[$GroupId].Add($UserId)
        }.GetNewClosure()
    }
}
