<#
.SYNOPSIS
    PowerShell module root for Bulk Identity Management (Entra ID bulk provisioning).

.DESCRIPTION
    This module will host CSV contract validation, identity derivation, IT department rules,
    a Microsoft Graph gateway, and apply orchestration. Task 1 establishes a loadable module
    layout; exact gallery pins live in BulkIdentityManagement.psd1 RequiredModules.

    Normative contract: CONTEXT.md at repository root.

.NOTES
    Requires PowerShell 7.2+ (see BulkIdentityManagement.psd1 when present). Default CI does not call
    Microsoft Graph; the dependency exists for local and guarded apply paths.
#>

Export-ModuleMember -Function @()
