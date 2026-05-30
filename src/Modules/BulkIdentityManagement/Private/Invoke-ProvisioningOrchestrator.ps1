<#
.SYNOPSIS
    Runs dry-run or apply provisioning for CSV rows against a Graph gateway contract.

.DESCRIPTION
    For each provisioning row: maps identity, derives UPN, resolves user and IT membership
    through the supplied gateway ScriptBlocks. Dry run performs read-only gateway calls only.
    Apply creates, skips, or updates users per CONTEXT re-run behavior and ensures IT group
    membership for qualifying rows. Row failures are collected; batch continues.

.PARAMETER ProvisioningRows
    Materialized rows from Import-ProvisioningCsv.

.PARAMETER GraphGateway
    Hashtable with six gateway ScriptBlocks per Task 7 contract.

.PARAMETER TenantDomainSuffix
    Tenant domain suffix for UPN derivation.

.PARAMETER ItMembershipGroupId
    Object ID of the pre-created IT membership group.

.PARAMETER DryRun
    When set, performs no mutating gateway operations.

.PARAMETER UpdateExisting
    When set, patches limited attributes for existing users.

.PARAMETER ItDepartmentTarget
    Department value that qualifies for IT membership ensure.

.PARAMETER UsageLocation
    Optional usage location applied on user create only.

.PARAMETER ShowIdentifiers
    Passed through to aggregate reporting.

.OUTPUTS
    PSCustomObject with RowOutcomes, ExitCode, and DryRun flag.

.NOTES
    Private function; not exported until Task 13 entry wiring.
#>

function Invoke-ProvisioningOrchestrator {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'DryRun switch prevents mutations; apply mutations are explicit gateway calls.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $ProvisioningRows,

        [Parameter(Mandatory)]
        [hashtable] $GraphGateway,

        [Parameter(Mandatory)]
        [string] $TenantDomainSuffix,

        [Parameter(Mandatory)]
        [string] $ItMembershipGroupId,

        [Parameter()]
        [switch] $DryRun,

        [Parameter()]
        [switch] $UpdateExisting,

        [Parameter()]
        [string] $ItDepartmentTarget = 'IT',

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $UsageLocation,

        [Parameter()]
        [switch] $ShowIdentifiers
    )

    Test-ProvisioningGraphGatewayContract -GraphGateway $GraphGateway

    $parsedGroupId = [guid]::Empty
    if (-not [guid]::TryParse($ItMembershipGroupId, [ref]$parsedGroupId)) {
        throw [System.ArgumentException]::new(
            'IT membership group id must be a valid GUID.',
            'ItMembershipGroupId')
    }

    $outcomes = [System.Collections.Generic.List[object]]::new()

    foreach ($row in $ProvisioningRows) {
        $lineNumber = [int] $row.SourceLineNumber
        try {
            $mapped = Get-MappedProvisioningIdentity -ProvisioningRow $row
            $resolvedUpn = Resolve-ProvisioningOrchestratorUserPrincipalName `
                -ProvisioningRow $row `
                -MappedProvisioningIdentity $mapped `
                -TenantDomainSuffix $TenantDomainSuffix `
                -GraphGateway $GraphGateway
            $upn = $resolvedUpn.UserPrincipalName
            $existingUserId = $resolvedUpn.ExistingUserId
            $qualifiesForItMembership = Test-ProvisioningDepartmentMatch `
                -Department $row.Department `
                -Target $ItDepartmentTarget

            $outcome = Invoke-ProvisioningOrchestratorRow `
                -Row $row `
                -Mapped $mapped `
                -UserPrincipalName $upn `
                -ExistingUserId $existingUserId `
                -QualifiesForItMembership $qualifiesForItMembership `
                -GraphGateway $GraphGateway `
                -ItMembershipGroupId $ItMembershipGroupId `
                -DryRun:$DryRun `
                -UpdateExisting:$UpdateExisting `
                -UsageLocation $UsageLocation

            $outcomes.Add($outcome)
        }
        catch {
            $reason = $_.Exception.Message
            if ($_.Exception.InnerException) {
                $reason = $_.Exception.InnerException.Message
            }

            $safeReason = Get-SanitizedProvisioningFailureReason -Message $reason

            $outcomes.Add((New-ProvisioningRowOutcome `
                -SourceLineNumber $lineNumber `
                -Status $ProvisioningRowOutcomeStatusFailed `
                -Reason $safeReason))
        }
    }

    $outcomeArray = @($outcomes.ToArray())
    return [pscustomobject]@{
        RowOutcomes = $outcomeArray
        ExitCode    = (Get-ProvisioningBatchExitCode -RowOutcomes $outcomeArray)
        DryRun      = [bool] $DryRun
        ShowIdentifiers = [bool] $ShowIdentifiers
    }
}

function Resolve-ProvisioningOrchestratorUserPrincipalName {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $ProvisioningRow,

        [Parameter(Mandatory)]
        [object] $MappedProvisioningIdentity,

        [Parameter(Mandatory)]
        [string] $TenantDomainSuffix,

        [Parameter(Mandatory)]
        [hashtable] $GraphGateway
    )

    $normalizedDomain = Get-NormalizedProvisioningTenantDomain -TenantDomainSuffix $TenantDomainSuffix
    $baseLocalPart = Get-ProvisioningUpnBaseLocalPart `
        -ProvisioningRow $ProvisioningRow `
        -MappedProvisioningIdentity $MappedProvisioningIdentity `
        -NormalizedDomain $normalizedDomain
    $baseUpn = Get-CanonicalProvisioningUpnCandidate `
        -BaseLocalPart $baseLocalPart `
        -NormalizedDomain $normalizedDomain `
        -AttemptIndex 0

    $existingUserId = & $GraphGateway.TestUpnExists $baseUpn
    if ($existingUserId) {
        return [pscustomobject]@{
            UserPrincipalName = $baseUpn
            ExistingUserId    = $existingUserId
        }
    }

    $derived = Get-DerivedUserPrincipalName `
        -ProvisioningRow $ProvisioningRow `
        -MappedProvisioningIdentity $MappedProvisioningIdentity `
        -TenantDomainSuffix $TenantDomainSuffix `
        -UpnExists $GraphGateway.TestUpnExists

    return [pscustomobject]@{
        UserPrincipalName = $derived.UserPrincipalName
        ExistingUserId    = (& $GraphGateway.TestUpnExists $derived.UserPrincipalName)
    }
}

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

function Get-ProvisioningOrchestratorNewUserProperties {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [object] $Row,

        [Parameter(Mandatory)]
        [object] $Mapped,

        [Parameter(Mandatory)]
        [string] $UserPrincipalName,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $UsageLocation
    )

    $properties = @{
        userPrincipalName = $UserPrincipalName
        mailNickname      = $Mapped.MailNickname
        givenName         = $Mapped.GivenName
        surname           = $Mapped.Surname
        displayName       = $Mapped.DisplayName
        department        = $Row.Department.Trim()
        accountEnabled    = $true
    }

    if (-not [string]::IsNullOrWhiteSpace($UsageLocation)) {
        $properties['usageLocation'] = $UsageLocation.Trim()
    }

    return $properties
}

function Get-ProvisioningOrchestratorUpdateProperties {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [object] $Row,

        [Parameter(Mandatory)]
        [object] $Mapped
    )

    return @{
        department  = $Row.Department.Trim()
        givenName   = $Mapped.GivenName
        surname     = $Mapped.Surname
        displayName = $Mapped.DisplayName
    }
}

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

function Invoke-ProvisioningOrchestratorItMembership {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [string] $UserId,

        [Parameter(Mandatory)]
        [string] $UserPrincipalName,

        [Parameter(Mandatory)]
        [hashtable] $GraphGateway,

        [Parameter(Mandatory)]
        [string] $ItMembershipGroupId,

        [Parameter(Mandatory)]
        [bool] $DryRun,

        [Parameter(Mandatory)]
        [string] $PrimaryStatus
    )

    if ([string]::IsNullOrWhiteSpace($UserId)) {
        if ($DryRun) {
            return $null
        }

        throw [System.InvalidOperationException]::new(
            "Cannot ensure IT membership for UPN '$UserPrincipalName' without a resolved user Object ID.")
    }

    [void] (& $GraphGateway.GetGroupById $ItMembershipGroupId)

    $isMember = & $GraphGateway.TestGroupMembership $UserId $ItMembershipGroupId
    if ($isMember) {
        return $null
    }

    if ($DryRun) {
        if ($PrimaryStatus -eq $ProvisioningRowOutcomeStatusSkipped) {
            return $ProvisioningRowOutcomeStatusMembershipEnsured
        }

        return $null
    }

    & $GraphGateway.AddGroupMember $UserId $ItMembershipGroupId

    if ($PrimaryStatus -eq $ProvisioningRowOutcomeStatusSkipped) {
        return $ProvisioningRowOutcomeStatusMembershipEnsured
    }

    return $null
}
