# My Notepad installer (Windows).
#   powershell -ExecutionPolicy Bypass -File install.ps1              -> Desktop shortcut only
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Reminders   -> also install the background reminder helper
# Everything is per-user; nothing needs administrator rights. Run uninstall.ps1 to undo.
param([switch]$Reminders)

$proj = $PSScriptRoot
$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") |
  Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { Write-Host "Microsoft Edge was not found. Open index.html in any Chromium browser instead."; exit 1 }

$ws = New-Object -ComObject WScript.Shell

# Desktop shortcut: opens the app in its own window (no tabs or address bar)
$lnk = $ws.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'My Notepad.lnk'))
$lnk.TargetPath = $edge
$lnk.Arguments = '--app="' + ([Uri](Join-Path $proj 'index.html')).AbsoluteUri + '"'
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
