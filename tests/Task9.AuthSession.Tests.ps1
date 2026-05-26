<#
.SYNOPSIS
    Pester tests for Connect-ProvisioningGraph (Task 9 - Auth Session).
.DESCRIPTION
    Validates input boundary checks (GUID, thumbprint, cert path/extension/private key)
    and Connect-MgGraph parameter forwarding. All tests mock Connect-MgGraph to keep CI
    Graph-free. See PRD-Task-9-Auth-Session.md and CONTEXT.md.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Get-Module -Name BulkIdentityManagement | Remove-Module -Force
}

Describe 'Connect-ProvisioningGraph' {

    Context 'Thumbprint parameter set - happy path' {
        It 'calls Connect-MgGraph with correct thumbprint parameters' {
            InModuleScope BulkIdentityManagement {
                Mock Connect-MgGraph {}

                $t = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
                $c = 'b2c3d4e5-f6a7-8901-bcde-f12345678901'
                $thumb = 'A1B2C3D4E5F6A7B8C9D0E1F2A3B4C5D6E7F8A9B0'

                Connect-ProvisioningGraph -TenantId $t -ClientId $c `
                    -CertificateThumbprint $thumb

                Should -Invoke Connect-MgGraph -Times 1 -Exactly -ParameterFilter {
                    $ClientId -eq $c -and
                    $TenantId -eq $t -and
                    $CertificateThumbprint -eq $thumb -and
                    $NoWelcome -eq $true
                }
            }
        }
    }

    Context 'TenantId GUID validation' {
        It 'throws InvalidOperationException for non-GUID TenantId' {
            InModuleScope BulkIdentityManagement {
                Mock Connect-MgGraph {}
                {
                    Connect-ProvisioningGraph -TenantId 'not-a-guid' `
                        -ClientId 'b2c3d4e5-f6a7-8901-bcde-f12345678901' `
                        -CertificateThumbprint 'A1B2C3D4E5F6A7B8C9D0E1F2A3B4C5D6E7F8A9B0'
                } | Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage "*TenantId*not a valid GUID*"
                Should -Invoke Connect-MgGraph -Times 0 -Exactly
            }
        }
    }

    Context 'ClientId GUID validation' {
        It 'throws InvalidOperationException for non-GUID ClientId' {
            InModuleScope BulkIdentityManagement {
                Mock Connect-MgGraph {}
                {
                    Connect-ProvisioningGraph -TenantId 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' `
                        -ClientId 'nope' `
                        -CertificateThumbprint 'A1B2C3D4E5F6A7B8C9D0E1F2A3B4C5D6E7F8A9B0'
                } | Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage "*ClientId*not a valid GUID*"
                Should -Invoke Connect-MgGraph -Times 0 -Exactly
            }
        }
    }

    Context 'Thumbprint format validation' {
        It 'throws for thumbprint shorter than 40 hex chars' {
            InModuleScope BulkIdentityManagement {
                Mock Connect-MgGraph {}
                {
                    Connect-ProvisioningGraph -TenantId 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' `
                        -ClientId 'b2c3d4e5-f6a7-8901-bcde-f12345678901' `
                        -CertificateThumbprint 'A1B2C3D4'
                } | Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage "*CertificateThumbprint*not a valid*"
                Should -Invoke Connect-MgGraph -Times 0 -Exactly
            }
        }

        It 'throws for thumbprint with non-hex characters' {
            InModuleScope BulkIdentityManagement {
                Mock Connect-MgGraph {}
                {
                    Connect-ProvisioningGraph -TenantId 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' `
                        -ClientId 'b2c3d4e5-f6a7-8901-bcde-f12345678901' `
                        -CertificateThumbprint 'ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ'
                } | Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage "*CertificateThumbprint*not a valid*"
                Should -Invoke Connect-MgGraph -Times 0 -Exactly
            }
        }
    }

    Context 'CertificatePath existence check' {
        It 'throws when certificate file does not exist' {
            InModuleScope BulkIdentityManagement {
                Mock Connect-MgGraph {}
                {
                    Connect-ProvisioningGraph -TenantId 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' `
                        -ClientId 'b2c3d4e5-f6a7-8901-bcde-f12345678901' `
                        -CertificatePath 'C:\nonexistent\fake.pfx'
                } | Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage "*Certificate file not found*"
                Should -Invoke Connect-MgGraph -Times 0 -Exactly
            }
        }
    }

    Context 'CertificatePath extension check' {
        It 'throws for .cer extension' {
            InModuleScope BulkIdentityManagement {
                Mock Connect-MgGraph {}
                $tempFile = Join-Path $TestDrive 'bad.cer'
                Set-Content -Path $tempFile -Value 'dummy'
                {
                    Connect-ProvisioningGraph -TenantId 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' `
                        -ClientId 'b2c3d4e5-f6a7-8901-bcde-f12345678901' `
                        -CertificatePath $tempFile
                } | Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage "*Expected a .pfx or .p12*"
                Should -Invoke Connect-MgGraph -Times 0 -Exactly
            }
        }

        It 'throws for .pem extension' {
            InModuleScope BulkIdentityManagement {
                Mock Connect-MgGraph {}
                $tempFile = Join-Path $TestDrive 'key.pem'
                Set-Content -Path $tempFile -Value 'dummy'
                {
                    Connect-ProvisioningGraph -TenantId 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' `
                        -ClientId 'b2c3d4e5-f6a7-8901-bcde-f12345678901' `
                        -CertificatePath $tempFile
                } | Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage "*Expected a .pfx or .p12*"
                Should -Invoke Connect-MgGraph -Times 0 -Exactly
            }
        }
    }

    Context 'PFX loading - no private key' {
        It 'throws when loaded certificate has no private key' {
            InModuleScope BulkIdentityManagement {
                Mock Connect-MgGraph {}

                $tempPfx = Join-Path $TestDrive 'noprivkey.pfx'
                $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new()
                $publicOnly = $cert.RawData
                if ($null -eq $publicOnly -or $publicOnly.Length -eq 0) {
                    $selfSigned = New-SelfSignedCertificate -DnsName 'test.local' `
                        -CertStoreLocation 'Cert:\CurrentUser\My' -NotAfter (Get-Date).AddMinutes(5)
                    $exported = $selfSigned.Export(
                        [System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
                    [System.IO.File]::WriteAllBytes($tempPfx, $exported)
                    Remove-Item "Cert:\CurrentUser\My\$($selfSigned.Thumbprint)" -Force
                }

                {
                    Connect-ProvisioningGraph -TenantId 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' `
                        -ClientId 'b2c3d4e5-f6a7-8901-bcde-f12345678901' `
                        -CertificatePath $tempPfx
                } | Should -Throw -ExceptionType ([System.InvalidOperationException])
                Should -Invoke Connect-MgGraph -Times 0 -Exactly
            }
        }
    }

    Context 'CertificatePath parameter set - happy path' {
        It 'calls Connect-MgGraph with loaded certificate' {
            InModuleScope BulkIdentityManagement {
                Mock Connect-MgGraph {}

                $tempPfx = Join-Path $TestDrive 'good.pfx'
                $selfSigned = New-SelfSignedCertificate -DnsName 'test.local' `
                    -CertStoreLocation 'Cert:\CurrentUser\My' -NotAfter (Get-Date).AddMinutes(5)
                $exported = $selfSigned.Export(
                    [System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, '')
                [System.IO.File]::WriteAllBytes($tempPfx, $exported)
                Remove-Item "Cert:\CurrentUser\My\$($selfSigned.Thumbprint)" -Force

                $t = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
                $c = 'b2c3d4e5-f6a7-8901-bcde-f12345678901'

                Connect-ProvisioningGraph -TenantId $t -ClientId $c -CertificatePath $tempPfx

                Should -Invoke Connect-MgGraph -Times 1 -Exactly -ParameterFilter {
                    $ClientId -eq $c -and
                    $TenantId -eq $t -and
                    $null -ne $Certificate -and
                    $NoWelcome -eq $true
                }
            }
        }
    }

    Context 'Connect-MgGraph failure wrapping' {
        It 'wraps Connect-MgGraph exception in InvalidOperationException with inner' {
            InModuleScope BulkIdentityManagement {
                Mock Connect-MgGraph { throw [System.Net.Http.HttpRequestException]::new('AADSTS700016: app not found') }

                $t = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
                $c = 'b2c3d4e5-f6a7-8901-bcde-f12345678901'
                $thumb = 'A1B2C3D4E5F6A7B8C9D0E1F2A3B4C5D6E7F8A9B0'

                $caught = $null
                try {
                    Connect-ProvisioningGraph -TenantId $t -ClientId $c -CertificateThumbprint $thumb
                }
                catch {
                    $caught = $_.Exception
                }

                $caught | Should -Not -BeNullOrEmpty
                $caught | Should -BeOfType ([System.InvalidOperationException])
                $caught.Message | Should -Match 'Failed to connect to Microsoft Graph'
                $caught.InnerException | Should -Not -BeNullOrEmpty
            }
        }
    }
}
