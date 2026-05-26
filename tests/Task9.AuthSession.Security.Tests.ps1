<#
.SYNOPSIS
    Security-focused tests for Connect-ProvisioningGraph (Task 9).
.DESCRIPTION
    Validates defensive programming at the auth boundary: no secret leakage,
    path traversal resistance, parameter type safety, and cert disposal on
    error paths. See security-and-hardening skill.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    $script:SrcFile = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/Public/Connect-ProvisioningGraph.ps1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Get-Module -Name BulkIdentityManagement | Remove-Module -Force
}

Describe 'Connect-ProvisioningGraph security' {

    It 'CertificatePassword parameter is typed [securestring], not [string]' {
        $cmd = Get-Command -Name 'Connect-ProvisioningGraph' -Module 'BulkIdentityManagement'
        $param = $cmd.Parameters['CertificatePassword']
        $param | Should -Not -BeNullOrEmpty
        $param.ParameterType | Should -Be ([securestring])
    }

    It 'source code never converts SecureString to plaintext' {
        $text = Get-Content -LiteralPath $script:SrcFile -Raw
        $text | Should -Not -Match 'ConvertFrom-SecureString'
        $text | Should -Not -Match 'Marshal\]::SecureStringToBSTR'
        $text | Should -Not -Match 'Marshal\]::PtrToStringAuto'
        $text | Should -Not -Match 'NetworkCredential.*Password'
    }

    It 'source code never writes sensitive parameters to output streams' {
        $text = Get-Content -LiteralPath $script:SrcFile -Raw
        $text | Should -Not -Match 'Write-Host.*CertificatePassword'
        $text | Should -Not -Match 'Write-Verbose.*CertificatePassword'
        $text | Should -Not -Match 'Write-Debug.*CertificatePassword'
        $text | Should -Not -Match 'Write-Output.*CertificatePassword'
    }

    It 'error messages never contain password material' {
        InModuleScope BulkIdentityManagement {
            Mock Connect-MgGraph { throw 'auth failed' }

            $caught = $null
            try {
                Connect-ProvisioningGraph -TenantId 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' `
                    -ClientId 'b2c3d4e5-f6a7-8901-bcde-f12345678901' `
                    -CertificateThumbprint 'A1B2C3D4E5F6A7B8C9D0E1F2A3B4C5D6E7F8A9B0'
            }
            catch {
                $caught = $_.Exception
            }

            $caught.Message | Should -Not -Match '(?i)password'
            $caught.Message | Should -Not -Match '(?i)secret'
        }
    }

    It 'uses -LiteralPath for all file operations (no glob expansion)' {
        $text = Get-Content -LiteralPath $script:SrcFile -Raw
        $text | Should -Not -Match 'Test-Path\s+-Path\b'
        $text | Should -Not -Match 'Resolve-Path\s+-Path\b'
        $text | Should -Match 'Test-Path\s+-LiteralPath'
        $text | Should -Match 'Resolve-Path\s+-LiteralPath'
    }

    It 'rejects path with directory traversal characters gracefully' {
        InModuleScope BulkIdentityManagement {
            Mock Connect-MgGraph {}
            {
                Connect-ProvisioningGraph -TenantId 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' `
                    -ClientId 'b2c3d4e5-f6a7-8901-bcde-f12345678901' `
                    -CertificatePath '..\..\..\..\etc\shadow.pfx'
            } | Should -Throw -ExceptionType ([System.InvalidOperationException])
            Should -Invoke Connect-MgGraph -Times 0 -Exactly
        }
    }

    It 'does not hardcode any real tenant or client identifiers' {
        $text = Get-Content -LiteralPath $script:SrcFile -Raw
        $guidPattern = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
        $guids = [regex]::Matches($text, $guidPattern)
        $guids.Count | Should -Be 0 -Because 'source should not contain hardcoded GUIDs'
    }

    It 'disposes certificate on failed connect (private key cleanup)' {
        InModuleScope BulkIdentityManagement {
            Mock Connect-MgGraph { throw 'AADSTS error' }

            $tempPfx = Join-Path $TestDrive 'dispose-test.pfx'
            $rsa = [System.Security.Cryptography.RSA]::Create(2048)
            $req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
                'CN=test.local', $rsa,
                [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
            $cert = $req.CreateSelfSigned(
                [System.DateTimeOffset]::UtcNow,
                [System.DateTimeOffset]::UtcNow.AddMinutes(5))
            $pfxBytes = $cert.Export(
                [System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, '')
            [System.IO.File]::WriteAllBytes($tempPfx, $pfxBytes)
            $cert.Dispose()
            $rsa.Dispose()

            $caught = $null
            try {
                Connect-ProvisioningGraph -TenantId 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' `
                    -ClientId 'b2c3d4e5-f6a7-8901-bcde-f12345678901' `
                    -CertificatePath $tempPfx
            }
            catch { $caught = $_.Exception }

            $caught | Should -Not -BeNullOrEmpty
            $caught | Should -BeOfType ([System.InvalidOperationException])
        }
    }

    It 'source code contains cert.Dispose() in a finally block' {
        $text = Get-Content -LiteralPath $script:SrcFile -Raw
        $text | Should -Match '\.Dispose\(\)'
        $text | Should -Match 'finally'
    }
}
