<#
.SYNOPSIS
    Generates a random user password as SecureString for New-MgUser.

.DESCRIPTION
    Produces a 32-character password with at least one upper, lower, digit, and symbol
    from the approved charset. Password is never logged or returned as plain text.

.OUTPUTS
    System.Security.SecureString
#>

function New-ProvisioningGraphUserPassword {
    [CmdletBinding()]
    [OutputType([System.Security.SecureString])]
    param()

    $targetPasswordLength = 32
    $upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    $lower = 'abcdefghijklmnopqrstuvwxyz'
    $digits = '0123456789'
    $symbols = '!@#$%&*-_+='
    $allCharArray = ($upper + $lower + $digits + $symbols).ToCharArray()

    $requiredSets = @(
        ,$upper.ToCharArray()
        ,$lower.ToCharArray()
        ,$digits.ToCharArray()
        ,$symbols.ToCharArray()
    )

    $passwordChars = [System.Collections.Generic.List[char]]::new()
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

    try {
        foreach ($set in $requiredSets) {
            $indexBytes = [byte[]]::new(4)
            $rng.GetBytes($indexBytes)
            $index = [BitConverter]::ToUInt32($indexBytes, 0) % $set.Length
            [void] $passwordChars.Add([char] $set[$index])
        }

        while ($passwordChars.Count -lt $targetPasswordLength) {
            $indexBytes = [byte[]]::new(4)
            $rng.GetBytes($indexBytes)
            $index = [BitConverter]::ToUInt32($indexBytes, 0) % $allCharArray.Length
            [void] $passwordChars.Add([char] $allCharArray[$index])
        }

        for ($shuffleIndex = $passwordChars.Count - 1; $shuffleIndex -gt 0; $shuffleIndex--) {
            $swapBytes = [byte[]]::new(4)
            $rng.GetBytes($swapBytes)
            $swapWith = [BitConverter]::ToUInt32($swapBytes, 0) % ($shuffleIndex + 1)
            $temp = $passwordChars[$shuffleIndex]
            $passwordChars[$shuffleIndex] = $passwordChars[$swapWith]
            $passwordChars[$swapWith] = $temp
        }

        if ($passwordChars.Count -ne $targetPasswordLength) {
            throw [System.InvalidOperationException]::new(
                "Password generation produced $($passwordChars.Count) characters; expected $targetPasswordLength.")
        }

        $plain = [string]::new($passwordChars.ToArray())
        return ConvertTo-SecureString -String $plain -AsPlainText -Force
    }
    finally {
        if ($null -ne $rng) {
            $rng.Dispose()
        }
    }
}
