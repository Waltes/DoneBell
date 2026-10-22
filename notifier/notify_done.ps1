# DoneBell "agent finished" hook. Call from any AI tool's stop/notify hook.
# If the user is AWAY (atComputer=false): chime + toast now, stamp lastReplyAt.
# If the user is AT the computer: stay silent (they can see the reply).
param(
  [string]$Message = "Reply ready - you are away"
)
$dir = Split-Path $MyInvocation.MyCommand.Path
$dataDir = Join-Path $env:APPDATA 'DoneBell'
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
$f = Join-Path $dataDir "status.json"
$notify = Join-Path $dir "notify.ps1"

$s = $null
if (Test-Path $f) { try { $s = Get-Content $f -Raw | ConvertFrom-Json } catch {} }
if (-not $s) { $s = @{ atComputer = $true; lastReplyAt = $null; lastUserMsgAt = $null; lastNudgeAt = $null } }

if (-not $s.atComputer) {
  & $notify "DoneBell" $Message
}
$s.lastReplyAt = (Get-Date).ToString("o")
$s | ConvertTo-Json | Set-Content $f -Encoding UTF8
