<#
.SYNOPSIS
    Canonical provisioning CSV header names for BulkIdentityManagement.

.DESCRIPTION
    Defines required and optional column names per CONTEXT.md Provisioning CSV format.
    Dot-sourced into the module scope by BulkIdentityManagement.psm1; not exported.
#>
[CmdletBinding()]
param()

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Header name arrays are consumed when dot-sourced into the BulkIdentityManagement module scope.')]
$RequiredProvisioningCsvHeaderNames = @(
    'FirstName'
    'LastName'
    'Department'
)

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Header name arrays are consumed when dot-sourced into the BulkIdentityManagement module scope.')]
$OptionalProvisioningCsvHeaderNames = @(
    'MailNickname'
    'UserPrincipalName'
    'GivenName'
    'Surname'
    'DisplayName'
)
