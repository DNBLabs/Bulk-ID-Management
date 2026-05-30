<#
.SYNOPSIS
    Tests whether a user is a member of a group via Get-MgGroupMember filter.

.PARAMETER UserId
    User Object ID (GUID).

.PARAMETER GroupId
    Group Object ID (GUID).

.OUTPUTS
    System.Boolean
#>

function Test-ProvisioningGraphGroupMembership {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $UserId,

        [Parameter(Mandatory)]
        [string] $GroupId
    )

    Test-ProvisioningGraphObjectId -Id $UserId -ParameterName 'UserId'
    Test-ProvisioningGraphObjectId -Id $GroupId -ParameterName 'GroupId'

    $members = Invoke-ProvisioningGraphCommand -OperationName 'TestGroupMembership' -Command {
        Get-MgGroupMember -GroupId $GroupId -Filter "id eq '$UserId'" -Top 1 -ErrorAction Stop
    }

    if ($null -eq $members) {
        return $false
    }

    if ($members -is [System.Array] -or $members -is [System.Collections.IList]) {
        return @($members).Count -gt 0
    }

    return $true
}
