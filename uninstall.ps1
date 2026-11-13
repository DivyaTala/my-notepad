# Removes what install.ps1 set up. Your notes are NOT deleted: they live in the browser's storage.
#   powershell -ExecutionPolicy Bypass -File uninstall.ps1
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
  Where-Object { $_.CommandLine -like '*reminder-helper\helper.ps1*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
$paths = @(
  (Join-Path ([Environment]::GetFolderPath('Desktop')) 'My Notepad.lnk'),
  (Join-Path ([Environment]::GetFolderPath('Startup')) 'My Notepad Reminders.lnk')
)
foreach ($p in $paths) { if (Test-Path $p) { Remove-Item $p -Force } }
$key = 'HKCU:\Software\Classes\AppUserModelId\MyNotepad.Reminders'
if (Test-Path $key) { Remove-Item $key -Recurse -Force }
$data = Join-Path $env:LOCALAPPDATA 'MyNotepad'
if (Test-Path $data) { Remove-Item $data -Recurse -Force }   # the helper's copy of event titles and times, and the desktop runtime
# Desktop-app notes are kept in %APPDATA%\MyNotepad. Delete that folder yourself only if you want the notes gone.
Write-Host "Removed the shortcuts and the reminder helper."
