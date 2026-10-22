# DoneBell notifier: Windows toast (fallback tray balloon) + selected chime at chosen volume.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File notify.ps1 "Title" "Body"
# Data dir: %APPDATA%\DoneBell
param(
  [string]$Title = "DoneBell",
  [string]$Body  = "Reply complete"
)

$msg = if ($Body) { $Body } else { "Reply complete" }
$dataDir = Join-Path $env:APPDATA 'DoneBell'

# sound selection + volume from DoneBell settings (config.json)
$soundList = @(
  "Windows Notify System Generic.wav",
  "Windows Notify.wav",
  "Windows Notify Calendar.wav",
  "Windows Notify Email.wav",
  "chimes.wav",
  "chord.wav",
  "ding.wav",
  "tada.wav"
)
$soundWav = "C:\Windows\Media\" + $soundList[0]
$soundVol = 0.70   # 0.0 - 1.0
$cfgPath = Join-Path $dataDir "config.json"
if (Test-Path $cfgPath) {
  try {
    $c = Get-Content $cfgPath -Raw | ConvertFrom-Json
    $i = [int]$c.sound
    if ($i -ge 0 -and $i -lt $soundList.Count) { $soundWav = "C:\Windows\Media\" + $soundList[$i] }
    if ($c.volume -ne $null) {
      $v = [int][math]::Max(0, [math]::Min(100, [double]$c.volume))
      $soundVol = $v / 100.0
    }
  } catch {}
}

function Show-Toast {
  try {
    $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime]
    $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
    $texts = $template.GetElementsByTagName("text")
    $texts.Item(0).AppendChild($template.CreateTextNode($Title)) | Out-Null
    $texts.Item(1).AppendChild($template.CreateTextNode($msg)) | Out-Null
    $audio = $template.CreateElement("audio")
    $audio.SetAttribute("silent", "true")   # we play the selected WAV ourselves
    $template.AppendChild($audio) | Out-Null
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("DoneBell")
    $notifier.Show($template)
    return $true
  } catch {
    return $false
  }
}

function Show-Balloon {
  try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $ni = New-Object System.Windows.Forms.NotifyIcon
    $ni.Icon = [System.Drawing.SystemIcons]::Information
    $ni.Visible = $true
    $ni.BalloonTipTitle = $Title
    $ni.BalloonTipText = $msg
    $ni.ShowBalloonTip(4000)
    Start-Sleep -Seconds 4
    $ni.Dispose()
    return $true
  } catch {
    return $false
  }
}

function Play-Sound {
  if (-not (Test-Path $soundWav)) {
    try { [System.Media.SystemSounds]::Beep.Play() } catch {}
    return $false
  }
  # volume-capable path: WPF MediaPlayer (honours $soundVol 0.0-1.0)
  try {
    Add-Type -AssemblyName PresentationCore
    $p = New-Object System.Windows.Media.MediaPlayer
    $p.Open((New-Object System.Uri($soundWav)))
    $p.Volume = $soundVol
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not $p.NaturalDuration.HasTimeSpan -and $sw.ElapsedMilliseconds -lt 2000) { Start-Sleep -Milliseconds 50 }
    $p.Position = [TimeSpan]::Zero
    $p.Play()
    $sw.Restart()
    $advanced = $false
    while ($sw.ElapsedMilliseconds -lt 8000) {
      Start-Sleep -Milliseconds 100
      if ($p.Position.Ticks -gt 0) { $advanced = $true }
      if ($advanced -and $p.NaturalDuration.HasTimeSpan -and $p.Position -ge $p.NaturalDuration.TimeSpan) { break }
    }
    $p.Close()
    if ($advanced) { return $true }
  } catch {}
  # fallback: SoundPlayer has no volume control, plays at system volume
  try {
    $sp = New-Object System.Media.SoundPlayer $soundWav
    $sp.PlaySync()
    return $true
  } catch {}
  try { [System.Media.SystemSounds]::Beep.Play() } catch {}
  return $false
}

$visualOk = Show-Toast
if (-not $visualOk) { $visualOk = Show-Balloon }
Play-Sound | Out-Null
if (-not $visualOk) { Write-Host "[DoneBell] $Title : $msg" }
