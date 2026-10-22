# DoneBell 🔔

**A liquid-glass presence widget that chimes when your AI coding agent finishes a turn.**

You send Claude Code / Codex a big task, walk away to make coffee — and come back to find it finished waiting 20 minutes ago. DoneBell fixes that: a frosted-glass floating widget that shows your presence status, chimes the moment an agent completes a reply, and re-nudges you every 5 minutes until you're back.

> Windows first (v1). macOS/Linux planned. — 界面语言自动跟随系统（中文/English）。

**中文简介**：DoneBell 是一个液态玻璃风格的桌面浮窗——你给 Claude Code / Codex 派完活离开电脑后，AI 答完会立刻响铃提醒；5 分钟没回来还会再催。点「在 / 离开」切换在场状态，玻璃浓度、明暗、位置、铃声、音量都在 ⚙ 面板即改即存。界面语言自动跟随 Windows 系统语言。

## What it does

- 🔮 **Liquid-glass floating widget** — real acrylic desktop blur, light/dark themes, draggable, snaps to screen corners
- 🟢 **Presence toggle** — tap 在 (here) / 离开 (away). Away is when the magic happens
- 🔔 **Completion chime** — when you're away and an agent finishes, DoneBell plays a toast + chime
- ⏰ **5-minute re-nudge** — still away and haven't responded? It chimes again, every 5 minutes
- ⚙️ **Settings on the glass** — blur intensity, theme, position, 8 system chimes, volume — all live, all saved
- 🤖 **Follows agents** — the widget appears while a configured agent process runs and quietly quits when you're done

## Supported agents (v1)

| Agent | Wiring | Auto-config |
|---|---|---|
| Claude Code | official `Stop` hook | `donebell init claude` |
| Codex CLI | official `notify` config | `donebell init codex` |
| Anything else | generic completion command | `donebell init` prints it |

## Install (Windows)

Download the latest installer from [Releases](https://github.com/Waltes/DoneBell/releases/latest):

👉 **[DoneBell-Setup-0.1.0.exe](https://github.com/Waltes/DoneBell/releases/latest)**

Run it, then wire your AI tools:

```bash
npx donebell init all   # auto-configures Claude Code + Codex CLI
```

## Install & run (from source)

```bash
git clone https://github.com/Waltes/DoneBell.git
cd DoneBell
npm install
npx donebell init all   # wire Claude Code + Codex automatically
npm start               # show the widget
```

## How it works

```
AI agent finishes a turn
        │  (Claude Code Stop hook / Codex notify event)
        ▼
notify_done.ps1  ── reads %APPDATA%\DoneBell\status.json
        │               user away? → toast + chime (at your chosen volume)
        ▼               stamps lastReplyAt
monitor.ps1 (background, every 15s)
        └─ away + no response for 5 min → chime again
```

The widget itself is an Electron window: borderless + transparent, acrylic blur injected via `SetWindowCompositionAttribute`, clipped to a rounded rect via `SetWindowRgn` (DPI-aware, works at 125%/150%/200% display scaling).

## Settings

Everything lives in the ⚙ panel on the widget and is saved instantly:

- **Glass opacity**, **light/dark theme**
- **Position** (4 screen corners)
- **Chime**: 8 Windows system sounds with live preview
- **Volume** (0–100%, applies to chime and nudges)

Config file: `%APPDATA%\DoneBell\config.json`
Status file: `%APPDATA%\DoneBell\status.json` (written by the widget, read by the hooks)

To follow different agent processes, edit `followProcesses` in `config.json` (default: `["claude", "codex"]`).

## Privacy

Everything is local. No network calls, no telemetry, no accounts. The only files touched are on your own disk.

## License

MIT
