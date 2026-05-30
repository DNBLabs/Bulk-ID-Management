<#
.SYNOPSIS
    Processes a single provisioning row through create, skip, update, and IT membership paths.

.PARAMETER Row
    Provisioning row.

.PARAMETER Mapped
    Mapped provisioning identity.

.PARAMETER UserPrincipalName
    Canonical UPN for the row.

.PARAMETER ExistingUserId
    Existing user Object ID when UPN already exists, otherwise null.

.PARAMETER QualifiesForItMembership
    Whether the IT department rule matched.

.PARAMETER GraphGateway
    Task 7 gateway hashtable.

.PARAMETER ItMembershipGroupId
    IT membership group Object ID.

.PARAMETER DryRun
    When true, performs no mutating gateway operations.

.PARAMETER UpdateExisting
    When true, patches limited attributes for existing users.

.PARAMETER UsageLocation
    Optional usage location for new user create.

.OUTPUTS
    Row outcome object from New-ProvisioningRowOutcome.
#>

function Invoke-ProvisioningOrchestratorRow {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $Row,

        [Parameter(Mandatory)]
        [object] $Mapped,

        [Parameter(Mandatory)]
        [string] $UserPrincipalName,

        [Parameter()]
        [AllowNull()]
        [string] $ExistingUserId,

        [Parameter(Mandatory)]
        [bool] $QualifiesForItMembership,

        [Parameter(Mandatory)]
        [hashtable] $GraphGateway,

        [Parameter(Mandatory)]
        [string] $ItMembershipGroupId,

        [Parameter(Mandatory)]
        [bool] $DryRun,

        [Parameter(Mandatory)]
        [bool] $UpdateExisting,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $UsageLocation
    )

    $lineNumber = [int] $Row.SourceLineNumber
    $userId = $ExistingUserId
    $status = $ProvisioningRowOutcomeStatusSkipped

    if ([string]::IsNullOrWhiteSpace($userId)) {
        if ($DryRun) {
            $status = $ProvisioningRowOutcomeStatusCreated
        }
        else {
            $newUserProperties = Get-ProvisioningOrchestratorNewUserProperties `
                -Row $Row -Mapped $Mapped -UserPrincipalName $UserPrincipalName -UsageLocation $UsageLocation
            $userId = & $GraphGateway.NewUser $newUserProperties
            $status = $ProvisioningRowOutcomeStatusCreated
        }
    }
    elseif ($UpdateExisting) {
        if ($DryRun) {
            $status = $ProvisioningRowOutcomeStatusUpdated
        }
        else {
            $patch = Get-ProvisioningOrchestratorUpdateProperties -Row $Row -Mapped $Mapped
            & $GraphGateway.UpdateUser $userId $patch
            $status = $ProvisioningRowOutcomeStatusUpdated
        }
    }

    if ($QualifiesForItMembership) {
        $membershipOutcome = Invoke-ProvisioningOrchestratorItMembership `
            -UserId $userId `
            -UserPrincipalName $UserPrincipalName `
            -GraphGateway $GraphGateway `
            -ItMembershipGroupId $ItMembershipGroupId `
            -DryRun:$DryRun `
            -PrimaryStatus $status

        if ($membershipOutcome) {
            $status = $membershipOutcome
        }
    }

    return New-ProvisioningRowOutcome `
        -SourceLineNumber $lineNumber `
        -Status $status `
        -UserPrincipalName $UserPrincipalName `
        -ObjectId $userId
}
