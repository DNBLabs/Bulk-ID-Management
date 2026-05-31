<#
.SYNOPSIS
    Tests whether a user is a member of a group via Microsoft Graph checkMemberGroups.

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

    $isMember = Invoke-ProvisioningGraphCommand -OperationName 'TestGroupMembership' -Command {
        $uri = "https://graph.microsoft.com/v1.0/users/$UserId/checkMemberGroups"
        $response = Invoke-MgGraphRequest -Method POST -Uri $uri -Body @{
            groupIds = @($GroupId)
        } -ErrorAction Stop

        $matchingGroupIds = @()
        if ($null -ne $response) {
            if ($null -ne $response.Value) {
                $matchingGroupIds = @($response.Value)
            }
            elseif ($null -ne $response.value) {
                $matchingGroupIds = @($response.value)
            }
        }

        return $matchingGroupIds -contains $GroupId
    }

    return [bool]$isMember
}
