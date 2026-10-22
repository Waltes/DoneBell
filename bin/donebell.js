#!/usr/bin/env node
// DoneBell CLI
//   donebell init [claude|codex|all]   wire the chime into installed AI agents
//   donebell start                     launch the widget
//   donebell help
'use strict';
const fs = require('fs');
const path = require('path');
const os = require('os');

const PKG_ROOT = path.resolve(__dirname, '..');
const NOTIFIER_DIR = path.join(PKG_ROOT, 'notifier');
const NOTIFY_DONE = path.join(NOTIFIER_DIR, 'notify_done.ps1');
const CODEX_NOTIFY = path.join(NOTIFIER_DIR, 'codex_notify.ps1');

function psPath(p) { return p; }                 // for -File args
function tomlPath(p) { return p.replace(/\\/g, '/'); } // TOML-friendly forward slashes

// ---------- Claude Code: Stop hook in ~/.claude/settings.json ----------
function initClaude() {
  const dir = path.join(os.homedir(), '.claude');
  const file = path.join(dir, 'settings.json');
  fs.mkdirSync(dir, { recursive: true });
  let settings = {};
  if (fs.existsSync(file)) {
    try { settings = JSON.parse(fs.readFileSync(file, 'utf8')); }
    catch (e) {
      const bak = file + '.donebell-bak';
      fs.copyFileSync(file, bak);
      console.log('  ! settings.json was invalid JSON; backed up to ' + bak);
      settings = {};
    }
  }
  settings.hooks = settings.hooks || {};
  settings.hooks.Stop = Array.isArray(settings.hooks.Stop) ? settings.hooks.Stop : [];
  const command = `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${psPath(NOTIFY_DONE)}" -Message "Claude Code reply ready"`;
  const already = JSON.stringify(settings.hooks.Stop).indexOf('notify_done.ps1') !== -1;
  if (!already) {
    settings.hooks.Stop.push({ matcher: '', hooks: [{ type: 'command', command }].concat([]) });
    fs.writeFileSync(file, JSON.stringify(settings, null, 2), 'utf8');
    console.log('  + Claude Code: Stop hook written to ' + file);
  } else {
    console.log('  = Claude Code: hook already present, skipped');
  }
}

// ---------- Codex CLI: notify entry in ~/.codex/config.toml ----------
function initCodex() {
  const dir = path.join(os.homedir(), '.codex');
  const file = path.join(dir, 'config.toml');
  fs.mkdirSync(dir, { recursive: true });
  let content = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  if (content.indexOf('codex_notify.ps1') !== -1) {
    console.log('  = Codex: notify entry already present, skipped');
    return;
  }
  const line = `notify = ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "${tomlPath(CODEX_NOTIFY)}"]`;
  content = content.replace(/\n*$/, '\n') + `\n# DoneBell: chime when a turn completes\n${line}\n`;
  fs.writeFileSync(file, content, 'utf8');
  console.log('  + Codex: notify entry written to ' + file);
}

// ---------- generic hook (for tools with custom stop hooks) ----------
function printGeneric() {
  console.log('  Generic hook command (any tool that can run a command on completion):');
  console.log(`    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${NOTIFY_DONE}" -Message "<tool name> reply ready"`);
}

function main() {
  const args = process.argv.slice(2);
  const cmd = (args[0] || 'help').toLowerCase();

  if (cmd === 'init') {
    const target = (args[1] || 'all').toLowerCase();
    console.log('DoneBell: wiring agents...');
    if (target === 'all' || target === 'claude') initClaude();
    if (target === 'all' || target === 'codex') initCodex();
    if (target === 'all') printGeneric();
    if (!['all', 'claude', 'codex'].includes(target)) {
      console.log('Unknown target: ' + target + ' (supported: claude, codex, all)');
      process.exitCode = 1;
    } else {
      console.log('Done. Run "donebell start" to show the widget.');
    }
    return;
  }

  if (cmd === 'start') {
    let electronBin = null;
    try { electronBin = require('electron'); } catch (e) { /* not installed here */ }
    if (typeof electronBin === 'string' && fs.existsSync(electronBin)) {
      const { spawn } = require('child_process');
      spawn(electronBin, [PKG_ROOT], { stdio: 'ignore', detached: true }).unref();
      console.log('DoneBell widget launched.');
    } else {
      console.log('Electron runtime not found. Run inside the project:  npm install && npm start');
      process.exitCode = 1;
    }
    return;
  }

  console.log([
    'DoneBell - chime when your AI agent finishes a turn',
    '',
    'Usage:',
    '  donebell init [claude|codex|all]   wire agents (default: all)',
    '  donebell start                     launch the widget',
    '  donebell help                      show this help'
  ].join('\n'));
}

main();
