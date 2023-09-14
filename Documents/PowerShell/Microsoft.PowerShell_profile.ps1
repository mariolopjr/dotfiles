# Disable powershell telemetry
$env:POWERSHELL_TELEMETRY_OPTOUT = $true

# Add starship to powershell
Invoke-Expression (&starship init powershell)
