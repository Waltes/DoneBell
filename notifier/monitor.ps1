# DoneBell monitor: runs in background. Re-nudges every 5 minutes while the user
# is AWAY and has not replied since the last agent reply. Heartbeat lock prevents
# duplicate instances. Data dir: %APPDATA%\DoneBell
param(
  [string]$NudgeMsg = "New reply waiting - not viewed for 5 minutes"
)
$dataDir = Join-Path $env:APPDATA 'DoneBell'
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
$statusFile = Join-Path $dataDir "status.json"
$lockFile   = Join-Path $dataDir ".monitor.lock"
$notify     = Join-Path (Split-Path $MyInvocation.MyCommand.Path) "notify.ps1"

function Write-Lock { @{ts=(Get-Date).ToString("o"); pid=$PID} | ConvertTo-Json | Set-Content $lockFile -Encoding UTF8 }

# exit if a fresh monitor is already alive
if (Test-Path $lockFile) {
  try {
    $hb = Get-Content $lockFile -Raw | ConvertFrom-Json
    if (((Get-Date) - [datetime]$hb.ts).TotalSeconds -lt 60) { exit }
  } catch {}
}
Write-Lock

while ($true) {
  Write-Lock
  try { $s = Get-Content $statusFile -Raw | ConvertFrom-Json } catch { Start-Sleep 15; continue }
  $now = Get-Date
  if (-not $s.atComputer) {
    $lastReply = if ($s.lastReplyAt)   { [datetime]$s.lastReplyAt }   else { $null }
    $lastUser  = if ($s.lastUserMsgAt) { [datetime]$s.lastUserMsgAt } else { $null }
    $lastNudge = if ($s.lastNudgeAt)   { [datetime]$s.lastNudgeAt }   else { $null }
    # only nudge if user has NOT interacted since the last reply
    if ($lastReply -and ($lastUser -eq $null -or $lastUser -le $lastReply)) {
      $sinceReply = ($now - $lastReply).TotalSeconds
      $sinceNudge = if ($lastNudge) { ($now - $lastNudge).TotalSeconds } else { 99999 }
      if ($sinceReply -ge 300 -and $sinceNudge -ge 300) {
        & $notify "DoneBell" $NudgeMsg
        $s.lastNudgeAt = $now.ToString("o")
        $s | ConvertTo-Json | Set-Content $statusFile -Encoding UTF8
      }
    }
  }
  Start-Sleep 15
}
