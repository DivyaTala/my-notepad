# My Notepad - background reminder helper
# Runs quietly in the background, keeps a copy of the calendar events the app sends it,
# and shows a Windows notification when a reminder is due, even if the app is closed.
# It only listens on this computer (localhost) and never talks to the internet.

$AppId = 'MyNotepad.Reminders'
$Port  = 47821
$dir   = Join-Path $env:LOCALAPPDATA 'MyNotepad'
New-Item -ItemType Directory -Force $dir | Out-Null
$stateFile = Join-Path $dir 'reminders.json'
$logFile   = Join-Path $dir 'helper.log'

function Log($m) { try { Add-Content -Path $logFile -Value ("{0}  {1}" -f (Get-Date -Format s), $m) -Encoding utf8 } catch {} }

[void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
[void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

# events: what the app sent. fired/seen/dismissed: per reminder, keyed by id + date + time + lead,
# so editing an event's time makes its reminder fire again.
$state = @{ events = @(); fired = @{}; seen = @{}; dismissed = @{} }

function Key($e) { "$($e.id)|$($e.date)|$($e.time)|$($e.lead)" }

function Save-State {
  try {
    @{ events = @($state.events); fired = @($state.fired.Keys); seen = @($state.seen.Keys); dismissed = @($state.dismissed.Keys) } |
      ConvertTo-Json -Depth 6 | Set-Content -Path $stateFile -Encoding utf8
  } catch { Log "save failed: $_" }
}
function Load-State {
  if (-not (Test-Path $stateFile)) { return }
  try {
    $j = Get-Content $stateFile -Raw -Encoding utf8 | ConvertFrom-Json
    $state.events = @($j.events | Where-Object { $_ })
    foreach ($n in 'fired', 'seen', 'dismissed') { foreach ($k in @($j.$n)) { if ($k) { $state[$n][[string]$k] = $true } } }
  } catch { Log "load failed: $_" }
}

function Show-Toast($title, $line, $tag, $place, $url) {
  $t = [System.Security.SecurityElement]::Escape([string]$title)
  $l = [System.Security.SecurityElement]::Escape([string]$line)
  # scenario='reminder' keeps the notification on screen until Dismiss is pressed
  # optional third line (location) and an "Open link" button when the event has a web link
  $third = ''; $open = ''
  if ($url -and ([string]$url) -match '^https?://') { $open = "<action content='Open link' activationType='protocol' arguments='" + [System.Security.SecurityElement]::Escape([string]$url) + "'/>" }
  elseif ($place) { $third = '<text>' + [System.Security.SecurityElement]::Escape([string]$place) + '</text>' }
  $xml = "<toast scenario='reminder'><visual><binding template='ToastGeneric'><text>$t</text><text>$l</text>$third</binding></visual>" +
         "<actions>$open<action activationType='system' arguments='dismiss' content=''/></actions>" +
         "<audio src='ms-winsoundevent:Notification.Reminder'/></toast>"
  $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
  $doc.LoadXml($xml)
  $toast = New-Object Windows.UI.Notifications.ToastNotification $doc
  $toast.Tag = [string]$tag; $toast.Group = 'rem'
  [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($toast)
}
function Remove-Toast($tag) { try { [Windows.UI.Notifications.ToastNotificationManager]::History.Remove([string]$tag, 'rem', $AppId) } catch { Log "remove failed for ${tag}: $_" } }
function Get-ToastTags { try { @([Windows.UI.Notifications.ToastNotificationManager]::History.GetHistory($AppId) | ForEach-Object { $_.Tag }) } catch { $null } }

function Get-Start($e) { try { [datetime]::ParseExact("$($e.date) $($e.time)", 'yyyy-MM-dd HH:mm', [cultureinfo]::InvariantCulture) } catch { $null } }

function Do-Timer {
  $now = Get-Date; $changed = $false; $tags = $null; $gotTags = $false
  foreach ($e in $state.events) {
    $k = Key $e
    if ($e.dismissed -or $state.dismissed[$k]) { continue }
    $start = Get-Start $e
    if (-not $start -or $now -ge $start.AddHours(12)) { continue }
    if (-not $state.fired[$k]) {
      if ($now -ge $start.AddMinutes(-[int]$e.lead)) {
        $mins = [int][math]::Round(($start - $now).TotalMinutes); $when = $start.ToString('h:mm tt')
        $line = if ($mins -ge 60) { "Starts at $when" } elseif ($mins -gt 0) { "Starts in $mins min, at $when" } elseif ($mins -eq 0) { "Starting now, $when" } else { "Started at $when" }
        try { Show-Toast $e.title $line $e.id $e.place $e.url; Log "notified: $($e.title) ($when)" } catch { Log "toast failed: $_" }
        $state.fired[$k] = $true; $changed = $true
      }
    } else {
      # Notification was shown. Once it has been seen in Windows' list and then disappears, the user dismissed it.
      if (-not $gotTags) { $tags = Get-ToastTags; $gotTags = $true }
      if ($null -eq $tags) { continue }
      if ($tags -contains [string]$e.id) { if (-not $state.seen[$k]) { $state.seen[$k] = $true; $changed = $true } }
      elseif ($state.seen[$k]) { $state.dismissed[$k] = $true; $changed = $true; Log "dismissed in Windows: $($e.title)" }
    }
  }
  if ($changed) { Save-State }
}

# How long the helper can sleep: until the next reminder is due, at most a minute.
# While a notification is showing it checks every 15 s whether it was dismissed in Windows.
function Next-Wait {
  $now = Get-Date; $ms = 60000
  foreach ($e in $state.events) {
    $k = Key $e
    if ($e.dismissed -or $state.dismissed[$k]) { continue }
    if ($state.fired[$k]) { $ms = [math]::Min($ms, 15000); continue }
    $start = Get-Start $e
    if (-not $start -or $now -ge $start.AddHours(12)) { continue }
    $left = ($start.AddMinutes(-[int]$e.lead) - $now).TotalMilliseconds
    if ($left -lt $ms) { $ms = [math]::Max(250, $left + 50) }
  }
  return [int]$ms
}

function Do-Sync($body) {
  $j = $body | ConvertFrom-Json
  $state.events = @($j.events | Where-Object { $_ -and $_.id })
  $keys = @{}
  foreach ($e in $state.events) {
    $k = Key $e; $keys[$k] = $true
    if ($e.dismissed -and -not $state.dismissed[$k]) { $state.dismissed[$k] = $true; if ($state.fired[$k]) { Remove-Toast $e.id } }
  }
  # an event that was deleted or re-timed while its notification is showing: take the old notification down
  foreach ($k in @($state.fired.Keys)) { if (-not $keys[$k] -and -not $state.dismissed[$k]) { Remove-Toast ($k -split '\|')[0] } }
  foreach ($n in 'fired', 'seen', 'dismissed') { foreach ($k in @($state[$n].Keys)) { if (-not $keys[$k]) { $state[$n].Remove($k) } } }
  Save-State
  Do-Timer
  $ids = @($state.events | Where-Object { $state.dismissed[(Key $_)] } | ForEach-Object { [string]$_.id })
  return (@{ ok = $true; dismissed = $ids } | ConvertTo-Json -Compress)
}

function Send($ctx, $code, $text, $origin) {
  $r = $ctx.Response; $r.StatusCode = $code
  if ($origin) { $r.Headers['Access-Control-Allow-Origin'] = $origin } else { $r.Headers['Access-Control-Allow-Origin'] = '*' }
  $r.Headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
  $r.Headers['Access-Control-Allow-Headers'] = 'Content-Type'
  $r.Headers['Access-Control-Allow-Private-Network'] = 'true'
  $r.Headers['Vary'] = 'Origin'
  $bytes = [Text.Encoding]::UTF8.GetBytes([string]$text)
  $r.ContentType = 'application/json; charset=utf-8'; $r.ContentLength64 = $bytes.Length
  if ($bytes.Length) { $r.OutputStream.Write($bytes, 0, $bytes.Length) }
  $r.Close()
}
function Handle($ctx) {
  $req = $ctx.Request; $origin = $req.Headers['Origin']
  # Only the notepad app (opened from a file) may talk to the helper; ordinary websites are refused.
  if ($origin -and $origin -notin @('null', 'file://')) { Send $ctx 403 '{"ok":false}' $null; return }
  if ($req.HttpMethod -eq 'OPTIONS') { Send $ctx 204 '' $origin; return }
  $path = $req.Url.AbsolutePath
  if ($path -eq '/ping') { Send $ctx 200 '{"ok":true}' $origin; return }
  if ($req.HttpMethod -eq 'POST' -and $path -eq '/sync') {
    $body = (New-Object IO.StreamReader($req.InputStream, [Text.Encoding]::UTF8)).ReadToEnd()
    if ($body.Length -gt 2000000) { Send $ctx 413 '{"ok":false}' $origin; return }
    Send $ctx 200 (Do-Sync $body) $origin; return
  }
  if ($req.HttpMethod -eq 'POST' -and $path -eq '/test') {
    Show-Toast 'Test reminder' 'This is how a reminder will look. Press Dismiss to close it.' 'test'
    Send $ctx 200 '{"ok":true}' $origin; return
  }
  Send $ctx 404 '{"ok":false}' $origin
}

Load-State
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
try { $listener.Start() } catch { Log "could not start (already running?): $_"; exit }
Log 'helper started'
$task = $listener.GetContextAsync()
while ($true) {
  try {
    if ($task.Wait((Next-Wait))) {
      $ctx = $task.Result; $task = $listener.GetContextAsync()
      try { Handle $ctx } catch { Log "request failed: $_"; try { $ctx.Response.Abort() } catch {} }
    }
  } catch { Log "listener error: $_"; Start-Sleep -Seconds 2; try { $task = $listener.GetContextAsync() } catch {} }
  try { Do-Timer } catch { Log "timer failed: $_" }
}
