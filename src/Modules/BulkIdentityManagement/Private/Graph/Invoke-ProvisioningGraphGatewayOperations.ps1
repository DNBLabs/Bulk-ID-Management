<#
.SYNOPSIS
    Task 7 Graph gateway operation implementations against Microsoft.Graph v1.0.

.DESCRIPTION
    Private functions invoked via ScriptBlock entries from New-ProvisioningGraphGateway.
    Each operation uses Invoke-ProvisioningGraphCommand for transient retry policy.
#>

function Invoke-ProvisioningGraphGatewayTestUpnExists {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '',
        Justification = 'TestUpnExists matches the Task 7 gateway contract name in CONTEXT.md.')]
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Upn
    )

    if ([string]::IsNullOrWhiteSpace($Upn)) {
        throw [System.InvalidOperationException]::new(
            'Graph validation failed: UPN must not be null or whitespace.')
    }

    $escapedUpn = ConvertTo-ProvisioningGraphODataLiteral -Value $Upn
    $filter = "userPrincipalName eq '$escapedUpn'"

    $users = Invoke-ProvisioningGraphCommand -OperationName 'TestUpnExists' -Command {
        Get-MgUser -Filter $filter -Property 'id' -Top 2 -ErrorAction Stop
    }

    if ($null -eq $users) {
        return $null
    }

    $userList = @($users)
    if ($userList.Count -eq 0) {
        return $null
    }

    if ($userList.Count -gt 1) {
        throw [System.InvalidOperationException]::new(
            "Graph TestUpnExists failed: multiple users matched UPN '$Upn'.")
    }

    return [string] $userList[0].Id
}

function Invoke-ProvisioningGraphGatewayNewUser {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Properties
    )

    $body = ConvertTo-ProvisioningGraphNewUserBody -Properties $Properties
    $password = New-ProvisioningGraphUserPassword

    $created = Invoke-ProvisioningGraphCommand -OperationName 'NewUser' -Command {
        $createBody = [ordered]@{}
        foreach ($entry in $body.GetEnumerator()) {
            $createBody[$entry.Key] = $entry.Value
        }

        $createBody['passwordProfile'] = @{
            Password                      = $password
            ForceChangePasswordNextSignIn = $true
        }

        New-MgUser -BodyParameter ([hashtable]$createBody) -ErrorAction Stop
    }

    if ($null -eq $created -or [string]::IsNullOrWhiteSpace($created.Id)) {
        throw [System.InvalidOperationException]::new(
            'Graph NewUser failed: created user did not return an Object ID.')
    }

    return [string] $created.Id
}

function Invoke-ProvisioningGraphGatewayUpdateUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $UserId,

        [Parameter(Mandatory)]
        [hashtable] $Properties
    )

    Test-ProvisioningGraphObjectId -Id $UserId -ParameterName 'UserId'
    $patch = ConvertTo-ProvisioningGraphPatchBody -Properties $Properties

    Invoke-ProvisioningGraphCommand -OperationName 'UpdateUser' -Command {
        Update-MgUser -UserId $UserId -BodyParameter $patch -ErrorAction Stop
    } | Out-Null
}

function Invoke-ProvisioningGraphGatewayGetGroupById {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string] $GroupId
    )

    Test-ProvisioningGraphObjectId -Id $GroupId -ParameterName 'GroupId'

    try {
        $group = Invoke-ProvisioningGraphCommand -OperationName 'GetGroupById' -Command {
            Get-MgGroup -GroupId $GroupId -ErrorAction Stop
        }
    }
    catch [System.InvalidOperationException] {
        if ($_.Exception.Message -match 'Resource .* does not exist|not found|404') {
            throw [System.InvalidOperationException]::new(
                'Graph GetGroupById failed: group not found.',
                $_.Exception)
        }

        throw
    }

    if ($null -eq $group) {
        throw [System.InvalidOperationException]::new(
            'Graph GetGroupById failed: group not found.')
    }

    return @{
        id          = [string] $group.Id
        displayName = $group.DisplayName
    }
}

function Invoke-ProvisioningGraphGatewayTestGroupMembership {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $UserId,

        [Parameter(Mandatory)]
        [string] $GroupId
    )

    Test-ProvisioningGraphGroupMembership -UserId $UserId -GroupId $GroupId
}

function Invoke-ProvisioningGraphGatewayAddGroupMember {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $UserId,

        [Parameter(Mandatory)]
        [string] $GroupId
    )

    Test-ProvisioningGraphObjectId -Id $UserId -ParameterName 'UserId'
    Test-ProvisioningGraphObjectId -Id $GroupId -ParameterName 'GroupId'

    $alreadyMember = Test-ProvisioningGraphGroupMembership -UserId $UserId -GroupId $GroupId
    if ($alreadyMember) {
        return
    }

    Invoke-ProvisioningGraphCommand -OperationName 'AddGroupMember' -Command {
        $reference = @{
            '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$UserId"
        }
        New-MgGroupMember -GroupId $GroupId -BodyParameter $reference -ErrorAction Stop
    } | Out-Null
}
