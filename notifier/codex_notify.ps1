# DoneBell adapter for Codex CLI's official notify mechanism.
# Codex calls: <program> '{"type":"agent-turn-complete", ...}' after each turn.
# The CLI installer (donebell init codex) registers this file in ~/.codex/config.toml.
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$NotifyArgs)

$payload = if ($NotifyArgs -and $NotifyArgs.Count -gt 0) { $NotifyArgs[$NotifyArgs.Count - 1] } else { '' }
$msg = 'Turn complete'
try {
  $j = $payload | ConvertFrom-Json
  if ($j.PSObject.Properties['type'] -and $j.type -ne 'agent-turn-complete') { exit 0 }
  $t = $j.'last-assistant-message'
  if ($t) {
    $t = ($t -replace '\s+', ' ').Trim()
    if ($t.Length -gt 80) { $t = $t.Substring(0, 80) + '...' }
    $msg = $t
  }
} catch {}
$done = Join-Path $PSScriptRoot 'notify_done.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $done -Message $msg
exit 0
