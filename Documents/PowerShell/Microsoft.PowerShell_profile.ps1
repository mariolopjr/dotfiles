# Add to path
Function Add-ToPathVariable {
    Param(
        [string] $NewPath
    )

    If (!(Test-Path $NewPath)) {
        Write-Warning "$NewPath does not exist"
        Return
    }

    $NewPathRegex = [regex]::Escape($NewPath)
    $CurrentPath = $env:Path
    $CurrentPathArray = $CurrentPath.Split(";") | Where-Object { $_ -notmatch "^$NewPathRegex\\?" }
    $env:Path = ($CurrentPathArray + $NewPath) -join ";"
}

# Not necessary since installer adds to env vars
#Add-ToPathVariable "C:\Users\mario\AppData\Roaming\Python\Python312\Scripts"

# Disable powershell telemetry
$env:POWERSHELL_TELEMETRY_OPTOUT = $true

# Add starship to powershell
Invoke-Expression (&starship init powershell)
