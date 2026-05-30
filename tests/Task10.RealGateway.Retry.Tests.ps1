<#
.SYNOPSIS
    Pester tests for Invoke-ProvisioningGraphCommand retry and error wrapping (Task 10).

.DESCRIPTION
    Uses synthetic exceptions with ProvisioningGraphStatusCode metadata. No live Graph.
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'
    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 10 - Invoke-ProvisioningGraphCommand retry policy' {

    It 'retries once on 429 then succeeds' {
        InModuleScope BulkIdentityManagement {
            $script:invokeCount = 0
            $delayScript = { param([int] $SecondsToWait) [void] $SecondsToWait }

            {
                Invoke-ProvisioningGraphCommand -OperationName 'Probe' -Command {
                    $script:invokeCount++
                    if ($script:invokeCount -lt 2) {
                        $ex = [System.InvalidOperationException]::new('Synthetic HTTP 429')
                        $ex.Data['ProvisioningGraphStatusCode'] = 429
                        throw $ex
                    }

                    return 'ok'
                } -MaxAttempts 5 -BaseDelaySeconds 1 -CumulativeWaitCapSeconds 90 -DelayScript $delayScript
            } | Should -Not -Throw

            $script:invokeCount | Should -Be 2
        }
    }

    It 'does not retry non-retryable 403 and preserves inner exception' {
        InModuleScope BulkIdentityManagement {
            $script:invokeCount = 0
            $inner = [System.InvalidOperationException]::new('Synthetic HTTP 403')
            $inner.Data['ProvisioningGraphStatusCode'] = 403

            $thrown = $null
            try {
                Invoke-ProvisioningGraphCommand -OperationName 'Denied' -Command {
                    $script:invokeCount++
                    throw $inner
                } -DelayScript { param($s) [void] $s }
            }
            catch {
                $thrown = $_
            }

            $script:invokeCount | Should -Be 1
            $thrown.Exception | Should -BeOfType [System.InvalidOperationException]
            $thrown.Exception.Message | Should -Match 'Graph Denied failed:'
            $thrown.Exception.InnerException | Should -Be $inner
        }
    }

    It 'stops after max attempts on persistent 429' {
        InModuleScope BulkIdentityManagement {
            $script:invokeCount = 0

            {
                Invoke-ProvisioningGraphCommand -OperationName 'Throttled' -Command {
                    $script:invokeCount++
                    $ex = [System.InvalidOperationException]::new('Synthetic HTTP 429')
                    $ex.Data['ProvisioningGraphStatusCode'] = 429
                    throw $ex
                } -MaxAttempts 5 -BaseDelaySeconds 0 -CumulativeWaitCapSeconds 90 -DelayScript { param($s) [void] $s }
            } | Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage 'Graph Throttled failed:*'

            $script:invokeCount | Should -Be 5
        }
    }

    It 'honors Retry-After over smaller exponential backoff' {
        InModuleScope BulkIdentityManagement {
            $script:invokeCount = 0
            $script:delays = [System.Collections.Generic.List[int]]::new()
            $delayScript = {
                param([int] $SecondsToWait)
                [void] $script:delays.Add($SecondsToWait)
            }

            {
                Invoke-ProvisioningGraphCommand -OperationName 'RetryAfter' -Command {
                    $script:invokeCount++
                    if ($script:invokeCount -lt 2) {
                        $ex = [System.InvalidOperationException]::new('Synthetic HTTP 429')
                        $ex.Data['ProvisioningGraphStatusCode'] = 429
                        $ex.Data['ProvisioningGraphRetryAfter'] = 7
                        throw $ex
                    }

                    return $true
                } -MaxAttempts 3 -BaseDelaySeconds 2 -CumulativeWaitCapSeconds 90 -DelayScript $delayScript
            } | Should -Not -Throw

            $script:delays[0] | Should -Be 7
        }
    }

    It 'fails when cumulative wait cap would be exceeded' {
        InModuleScope BulkIdentityManagement {
            $script:invokeCount = 0

            {
                Invoke-ProvisioningGraphCommand -OperationName 'Capped' -Command {
                    $script:invokeCount++
                    $ex = [System.InvalidOperationException]::new('Synthetic HTTP 503')
                    $ex.Data['ProvisioningGraphStatusCode'] = 503
                    $ex.Data['ProvisioningGraphRetryAfter'] = 91
                    throw $ex
                } -MaxAttempts 5 -BaseDelaySeconds 2 -CumulativeWaitCapSeconds 90 -DelayScript { param($s) [void] $s }
            } | Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage '*cumulative wait cap exceeded*'

            $script:invokeCount | Should -Be 1
        }
    }
}
