. (Join-Path $PSScriptRoot 'workshop_env.ps1')
Set-Location (Split-Path -Parent $PSScriptRoot)
flutter run -d edge
