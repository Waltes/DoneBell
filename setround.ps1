# DoneBell: clips the widget window to a rounded rectangle (CSS radius 22 @ 296 width)
# and injects acrylic blur-behind (respects window region, unlike DWM backdrop material).
$ErrorActionPreference = 'Stop'
Add-Type @"
using System;using System.Text;using System.Runtime.InteropServices;
public class WinRgn {
  public delegate bool CB(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(CB cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder sb, int n);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("gdi32.dll")] public static extern IntPtr CreateRoundRectRgn(int x1, int y1, int x2, int y2, int w, int h);
  [DllImport("user32.dll")] public static extern bool SetWindowRgn(IntPtr h, IntPtr rgn, bool redraw);
  [DllImport("user32.dll")] public static extern int SetWindowCompositionAttribute(IntPtr h, ref ATTRIB_DATA d);
  public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)]
  public struct ACCENT_POLICY { public int AccentState; public int AccentFlags; public uint GradientColor; public int AnimationId; }
  [StructLayout(LayoutKind.Sequential)]
  public struct ATTRIB_DATA { public int Attribute; public IntPtr Data; public int SizeOfData; }
}
"@

[WinRgn]::SetProcessDPIAware() | Out-Null   # measure true physical pixels (display may be scaled)

$dataDir = Join-Path $env:APPDATA 'DoneBell'
$logPath = Join-Path $dataDir 'setround.log'

# pick blur tint from saved theme (light -> cool white, dark -> deep slate)
$tint = 0x66E8E0F0
try {
  $cfg = Get-Content (Join-Path $dataDir 'config.json') -Raw | ConvertFrom-Json
  if ($cfg.theme -eq 'dark') { $tint = 0x66281E28 }   # ABGR for dark slate
} catch {}

$hwnd = [IntPtr]::Zero
$cb = [WinRgn+CB]{ param($h, $l)
  if ([WinRgn]::IsWindowVisible($h)) {
    $sb = New-Object System.Text.StringBuilder 256
    [WinRgn]::GetWindowText($h, $sb, 256) | Out-Null
    if ($sb.ToString() -eq 'DoneBell') { $script:hwnd = $h; return $false }
  }
  return $true
}
[WinRgn]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
if ($hwnd -eq [IntPtr]::Zero) { "no window" | Out-File $logPath -Encoding ascii; exit 1 }
$r = New-Object WinRgn+RECT
[WinRgn]::GetClientRect($hwnd, [ref]$r) | Out-Null
$w = $r.Right - $r.Left
$h = $r.Bottom - $r.Top
if ($w -le 0 -or $h -le 0) { exit 1 }
# CSS radius 22px at 296 CSS px width -> scale to actual physical pixels
$rad = [int][Math]::Round($w * 22 / 296)
$rgn = [WinRgn]::CreateRoundRectRgn(0, 0, $w + 1, $h + 1, $rad, $rad)
$ok = [WinRgn]::SetWindowRgn($hwnd, $rgn, $true)

$pol = New-Object WinRgn+ACCENT_POLICY
$pol.AccentState = 4          # ACCENT_ENABLE_ACRYLICBLURBEHIND
$pol.AccentFlags = 2
$pol.GradientColor = $tint
$pol.AnimationId = 0
$ptr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal([System.Runtime.InteropServices.Marshal]::SizeOf($pol))
[System.Runtime.InteropServices.Marshal]::StructureToPtr($pol, $ptr, $false)
$data = New-Object WinRgn+ATTRIB_DATA
$data.Attribute = 19          # WCA_ACCENT_POLICY
$data.Data = $ptr
$data.SizeOfData = [System.Runtime.InteropServices.Marshal]::SizeOf($pol)
$acc = [WinRgn]::SetWindowCompositionAttribute($hwnd, [ref]$data)
[System.Runtime.InteropServices.Marshal]::FreeHGlobal($ptr)

"w=${w} h=${h} rad=${rad} set=$ok accent=$acc tint=$tint" | Out-File $logPath -Encoding ascii
exit 0
