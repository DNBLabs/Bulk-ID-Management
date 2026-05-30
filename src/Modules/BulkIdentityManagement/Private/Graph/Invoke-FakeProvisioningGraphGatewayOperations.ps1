<#
.SYNOPSIS
    In-memory implementations of Task 7 gateway operations for tests and CI.

.DESCRIPTION
    Each function mutates or reads the caller-supplied State hashtable (Users, UpnIndex,
    Groups, Members). Used by New-FakeProvisioningGraphGateway via thin ScriptBlock wrappers.
#>

function Invoke-FakeProvisioningGraphGatewayTestUpnExists {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $State,

        [Parameter(Mandatory)]
        [string] $Upn
    )

    $key = $Upn.ToLowerInvariant()
    if ($State.UpnIndex.ContainsKey($key)) {
        return $State.UpnIndex[$key]
    }

    return $null
}

function Invoke-FakeProvisioningGraphGatewayNewUser {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $State,

        [Parameter(Mandatory)]
        [hashtable] $Properties
    )

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
}

function Invoke-FakeProvisioningGraphGatewayUpdateUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $State,

        [Parameter(Mandatory)]
        [string] $UserId,

        [Parameter(Mandatory)]
        [hashtable] $Properties
    )

    if (-not $State.Users.ContainsKey($UserId)) {
        throw [System.InvalidOperationException]::new(
            "User with Object ID '$UserId' not found.")
    }

    $existing = $State.Users[$UserId]
    foreach ($patchKey in $Properties.Keys) {
        $existing[$patchKey] = $Properties[$patchKey]
    }
}

function Invoke-FakeProvisioningGraphGatewayGetGroupById {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $State,

        [Parameter(Mandatory)]
        [string] $GroupId
    )

    if (-not $State.Groups.ContainsKey($GroupId)) {
        throw [System.InvalidOperationException]::new(
            "Group with Object ID '$GroupId' not found.")
    }

    return $State.Groups[$GroupId]
}

function Invoke-FakeProvisioningGraphGatewayTestGroupMembership {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $State,

        [Parameter(Mandatory)]
        [string] $UserId,

        [Parameter(Mandatory)]
        [string] $GroupId
    )

    if (-not $State.Members.ContainsKey($GroupId)) {
        $State.Members[$GroupId] = [System.Collections.Generic.HashSet[string]]::new()
    }

    return $State.Members[$GroupId].Contains($UserId)
}

function Invoke-FakeProvisioningGraphGatewayAddGroupMember {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $State,

        [Parameter(Mandatory)]
        [string] $UserId,

        [Parameter(Mandatory)]
        [string] $GroupId
    )

    if (-not $State.Groups.ContainsKey($GroupId)) {
        throw [System.InvalidOperationException]::new(
            "Group with Object ID '$GroupId' not found.")
    }

    if (-not $State.Members.ContainsKey($GroupId)) {
        $State.Members[$GroupId] = [System.Collections.Generic.HashSet[string]]::new()
    }

    [void] $State.Members[$GroupId].Add($UserId)
}
