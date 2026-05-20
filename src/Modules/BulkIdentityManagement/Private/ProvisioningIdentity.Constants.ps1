<#
.SYNOPSIS
    Length and boundary constants for provisioning identity mapping.

.DESCRIPTION
    Entra-aligned maximum lengths for mapped identity fields and bounded pre-normalization
    nickname input to limit processing of untrusted CSV cell text. Dot-sourced into module scope.

.NOTES
    mailNickname: Microsoft Graph user resource (64 characters).
    givenName/surname: 64 characters.
    displayName: 256 characters.
#>
[CmdletBinding()]
param()

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Constants are consumed when dot-sourced into the BulkIdentityManagement module scope.')]
$MaxProvisioningIdentityGivenNameLength = 64

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Constants are consumed when dot-sourced into the BulkIdentityManagement module scope.')]
$MaxProvisioningIdentitySurnameLength = 64

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Constants are consumed when dot-sourced into the BulkIdentityManagement module scope.')]
$MaxProvisioningIdentityDisplayNameLength = 256

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Constants are consumed when dot-sourced into the BulkIdentityManagement module scope.')]
$MaxProvisioningMailNicknameLength = 64

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Constants are consumed when dot-sourced into the BulkIdentityManagement module scope.')]
$MaxProvisioningMailNicknameInputLength = 512

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Constants are consumed when dot-sourced into the BulkIdentityManagement module scope.')]
$MaxProvisioningTenantDomainSuffixLength = 255

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Constants are consumed when dot-sourced into the BulkIdentityManagement module scope.')]
$MaxProvisioningUserPrincipalNameLength = 113

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Constants are consumed when dot-sourced into the BulkIdentityManagement module scope.')]
$MaxProvisioningCsvUserPrincipalNameInputLength = 113

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Constants are consumed when dot-sourced into the BulkIdentityManagement module scope.')]
$MinProvisioningMaximumUpnCandidates = 1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Constants are consumed when dot-sourced into the BulkIdentityManagement module scope.')]
$MaxProvisioningMaximumUpnCandidates = 99

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Constants are consumed when dot-sourced into the BulkIdentityManagement module scope.')]
$DefaultProvisioningMaximumUpnCandidates = 10
