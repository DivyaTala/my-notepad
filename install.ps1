# My Notepad installer (Windows).
#   powershell -ExecutionPolicy Bypass -File install.ps1              -> Desktop shortcut that opens the app through Microsoft Edge
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Desktop     -> Desktop shortcut for the real desktop app (Windows 11 Mica look; needs Node.js)
#   add -Reminders to either one to also install the background reminder helper
# Everything is per-user; nothing needs administrator rights. Run uninstall.ps1 to undo.
param([switch]$Desktop, [switch]$Reminders)

$proj = $PSScriptRoot
$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'My Notepad.lnk'))

if ($Desktop) {
  # Desktop app: the Electron runtime is installed once into your local app data folder (about 350 MB)
  if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { Write-Host "Node.js is needed for the desktop app. Install it from https://nodejs.org and run this again."; exit 1 }
  $rt = Join-Path $env:LOCALAPPDATA 'MyNotepad\runtime'
  New-Item -ItemType Directory -Force $rt | Out-Null
  if (-not (Test-Path "$rt\package.json")) { '{ "name": "my-notepad-runtime", "private": true }' | Set-Content "$rt\package.json" -Encoding ascii }
  $exe = Join-Path $rt 'node_modules\electron\dist\electron.exe'
  if (-not (Test-Path $exe)) {
    Write-Host "Downloading the desktop runtime. This can take a few minutes..."
    Push-Location $rt; npm install electron --no-audit --no-fund --loglevel=error; Pop-Location
    # some npm versions skip the package's own download step, so run it directly if the program is still missing
    if (-not (Test-Path $exe)) { Push-Location (Join-Path $rt 'node_modules\electron'); node install.js; Pop-Location }
  }
  if (-not (Test-Path $exe)) { Write-Host "The desktop runtime could not be installed."; exit 1 }
  $lnk.TargetPath = $exe
  $lnk.Arguments = '"' + (Join-Path $proj 'desktop') + '"'
} else {
  $edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $edge) { Write-Host "Microsoft Edge was not found. Open index.html in any Chromium browser instead."; exit 1 }
  $lnk.TargetPath = $edge
  $lnk.Arguments = '--app="' + ([Uri](Join-Path $proj 'index.html')).AbsoluteUri + '"'
}
$lnk.IconLocation = Join-Path $proj 'icon.ico'
$lnk.WorkingDirectory = $proj
$lnk.Save()
Write-Host "Created the 'My Notepad' shortcut on your Desktop."

if ($Reminders) {
  # Name and icon shown on the Windows notifications
  $key = 'HKCU:\Software\Classes\AppUserModelId\MyNotepad.Reminders'
  New-Item -Path $key -Force | Out-Null
  Set-ItemProperty -Path $key -Name DisplayName -Value 'My Notepad'
  Set-ItemProperty -Path $key -Name IconUri -Value (Join-Path $proj 'icon.png')

  # Start the helper at sign-in, and start it now
  $vbs = Join-Path $proj 'reminder-helper\start-helper.vbs'
  $s = $ws.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Startup')) 'My Notepad Reminders.lnk'))
  $s.TargetPath = "$env:WINDIR\System32\wscript.exe"
  $s.Arguments = '"' + $vbs + '"'
  $s.WorkingDirectory = Join-Path $proj 'reminder-helper'
  $s.IconLocation = Join-Path $proj 'icon.ico'
  $s.Save()
  Start-Process "$env:WINDIR\System32\wscript.exe" -ArgumentList ('"' + $vbs + '"')
  Write-Host "Installed the reminder helper. It starts with Windows and is running now."
}
Write-Host "Done. Do not move or rename this folder afterwards: the shortcut and helper point at it."
