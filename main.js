// DoneBell - liquid-glass presence widget that chimes when AI agents finish a turn
// Windows v1. Data dir: %APPDATA%\DoneBell (userData)
const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const fs = require('fs');
const { execFile, spawn } = require('child_process');

app.disableHardwareAcceleration();
let win = null;
let visible = true;

const DEFAULT_CFG = {
  theme: 'light',
  glassAlpha: 45,
  position: 'top-right',
  sound: 0,
  volume: 70,
  followProcesses: ['claude', 'codex']  // widget shows while any of these runs
};

function dataDir() { return app.getPath('userData'); }
function statusPath() { return path.join(dataDir(), 'status.json'); }
function configPath() { return path.join(dataDir(), 'config.json'); }

function readConfig() {
  try { return Object.assign({}, DEFAULT_CFG, JSON.parse(fs.readFileSync(configPath(), 'utf8'))); }
  catch (e) { return Object.assign({}, DEFAULT_CFG); }
}
function writeConfig(c) {
  try { fs.mkdirSync(dataDir(), { recursive: true }); fs.writeFileSync(configPath(), JSON.stringify(c), 'utf8'); } catch (e) {}
}
function readStatus() {
  try { return JSON.parse(fs.readFileSync(statusPath(), 'utf8')); }
  catch (e) { return { atComputer: true, lastReplyAt: null, lastUserMsgAt: null, lastNudgeAt: null }; }
}
function writeStatus(s) {
  try { fs.mkdirSync(dataDir(), { recursive: true }); fs.writeFileSync(statusPath(), JSON.stringify(s), 'utf8'); } catch (e) {}
}
function dlog(msg) {
  try { fs.mkdirSync(dataDir(), { recursive: true }); fs.appendFileSync(path.join(dataDir(), 'debug.log'), new Date().toISOString() + ' ' + msg + '\n'); } catch (e) {}
}

// clip window to rounded corners so the accent blur does not show square corner patches
function runSetRound() {
  const p = spawn('powershell.exe',
    ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File',
     path.join(__dirname, 'setround.ps1')],
    { detached: true, stdio: 'ignore' });
  p.unref();
}

function anyAgentRunning(cb) {
  const names = readConfig().followProcesses || DEFAULT_CFG.followProcesses;
  let pending = names.length;
  let found = false;
  if (!pending) return cb(false);
  for (const name of names) {
    execFile('tasklist', ['/FI', 'IMAGENAME eq ' + name + '.exe', '/NH'], (err, stdout) => {
      if (!err && String(stdout).toLowerCase().indexOf(name.toLowerCase() + '.exe') !== -1) found = true;
      if (--pending === 0) cb(found);
    });
  }
}

function placeWindow(pos) {
  const { screen } = require('electron');
  const wa = screen.getPrimaryDisplay().workArea;
  const W = 296, H = win.getBounds().height, M = 16;
  let x, y;
  switch (pos) {
    case 'top-left':     x = wa.x + M;            y = wa.y + M; break;
    case 'bottom-left':  x = wa.x + M;            y = wa.y + wa.height - H - M; break;
    case 'bottom-right': x = wa.x + wa.width - W - M; y = wa.y + wa.height - H - M; break;
    default:             x = wa.x + wa.width - W - M; y = wa.y + M; break;
  }
  win.setPosition(x, y);
}

function createWindow() {
  win = new BrowserWindow({
    width: 296,
    height: 124,
    frame: false,
    transparent: true,
    resizable: false,
    movable: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    hasShadow: false,
    roundedCorners: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });
  win.setAlwaysOnTop(true, 'screen-saver');
  win.loadFile('index.html');
  dlog('window created');
  win.on('close', () => dlog('window close event'));
  win.on('closed', () => dlog('window closed'));
  win.webContents.on('render-process-gone', (e, d) => dlog('renderer gone: ' + JSON.stringify(d)));
  win.once('ready-to-show', () => {
    placeWindow(readConfig().position); win.show(); dlog('shown');
    setTimeout(runSetRound, 600);
  });

  // lifecycle follows the configured agent processes
  let seenRunning = false;
  let missCount = 0;
  const MISS_QUIT = 20;   // 20 x 3s = 60s grace after agents close
  const MISS_BOOT = 100;  // never seen an agent: give up after 5 min
  setInterval(() => {
    anyAgentRunning((running) => {
      if (running) {
        missCount = 0;
        if (!seenRunning) { seenRunning = true; dlog('agent detected, attaching'); }
        if (!visible) { visible = true; win.show(); }
      } else {
        missCount++;
        if (visible && seenRunning) { visible = false; win.hide(); }
        const limit = seenRunning ? MISS_QUIT : MISS_BOOT;
        if (missCount >= limit) {
          dlog('agents gone, quitting (seen=' + seenRunning + ')');
          app.quit();
        }
      }
    });
  }, 3000);

  if (process.argv.includes('--shot')) {
    setTimeout(async () => {
      try {
        const img = await win.webContents.capturePage();
        fs.writeFileSync(path.join(app.getPath('pictures') || dataDir(), 'donebell_shot.png'), img.toPNG());
        dlog('shot saved');
      } catch (e) { dlog('shot failed: ' + e.message); }
    }, 4000);
  }
}

ipcMain.handle('get-state', () => readStatus().atComputer !== false);
ipcMain.handle('set-state', (e, at) => {
  const s = readStatus();
  s.atComputer = !!at;
  writeStatus(s);
  return s.atComputer;
});
ipcMain.on('close', () => { dlog('ipc close'); app.quit(); });

ipcMain.handle('get-config', () => readConfig());
ipcMain.handle('set-config', (e, c) => {
  const merged = Object.assign(readConfig(), c || {});
  writeConfig(merged);
  return merged;
});
ipcMain.handle('set-pos', (e, pos) => {
  const cfg = readConfig();
  cfg.position = pos;
  writeConfig(cfg);
  placeWindow(pos);
  return true;
});
ipcMain.handle('set-view', (e, settings) => {
  const h = settings ? 372 : 124;
  win.setSize(296, h);
  setTimeout(runSetRound, 150);
  return true;
});
ipcMain.on('preview-sound', (e, file) => {
  const safe = String(file || '').replace(/[^a-zA-Z0-9 ._-]/g, '');
  const p = 'C:\\Windows\\Media\\' + safe;
  dlog('preview-sound ipc: ' + safe + ' exists=' + fs.existsSync(p));
  if (!fs.existsSync(p)) return;
  const ps = spawn('powershell.exe',
    ['-NoProfile', '-Command', `(New-Object Media.SoundPlayer '${p}').PlaySync()`],
    { detached: true, stdio: 'ignore' });
  ps.unref();
});

app.whenReady().then(() => {
  fs.mkdirSync(dataDir(), { recursive: true });
  createWindow();
  // start the 5-minute re-nudge monitor (it exits on its own if another copy is alive)
  const m = spawn('powershell.exe',
    ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File',
     path.join(__dirname, 'notifier', 'monitor.ps1')],
    { detached: true, stdio: 'ignore' });
  m.unref();
});
app.on('window-all-closed', () => app.quit());
