'use strict';

const { app, BrowserWindow, Tray, Menu, ipcMain, nativeImage, shell } = require('electron');
const { spawn, execSync } = require('child_process');
const path  = require('path');
const http  = require('http');
const fs    = require('fs');
const os    = require('os');

// ── Constants ──────────────────────────────────────────────────────────────
const HUB_PORT    = 8080;
const OLLAMA_PORT = 11434;
const WEBUI_PORT  = 3000;
const CLAW_PORT   = 18789;

const IS_DEV  = !app.isPackaged;
const HUB_DIR = IS_DEV
  ? path.join(__dirname, '..', 'hub')
  : path.join(process.resourcesPath, 'hub');

// ── State ──────────────────────────────────────────────────────────────────
let mainWindow  = null;
let splashWindow = null;
let tray        = null;
let appIcon     = null;
let isQuitting  = false;
const procs     = {};

// ── Single instance ────────────────────────────────────────────────────────
if (!app.requestSingleInstanceLock()) { app.quit(); process.exit(0); }
app.on('second-instance', () => {
  if (mainWindow) { if (mainWindow.isMinimized()) mainWindow.restore(); mainWindow.focus(); }
});

// ── Port helpers ───────────────────────────────────────────────────────────
function portOpen(port) {
  return new Promise(resolve => {
    const req = http.request({ hostname:'127.0.0.1', port, method:'HEAD', timeout:800 }, () => resolve(true));
    req.on('error', () => resolve(false));
    req.on('timeout', () => { req.destroy(); resolve(false); });
    req.end();
  });
}

function waitPort(port, ms = 60000) {
  return new Promise(resolve => {
    const end = Date.now() + ms;
    const poll = () => portOpen(port).then(ok => {
      if (ok) return resolve(true);
      if (Date.now() >= end) return resolve(false);
      setTimeout(poll, 1200);
    });
    poll();
  });
}

// ── Splash status ──────────────────────────────────────────────────────────
function status(msg, pct) {
  console.log(`[NeuralBox] ${pct}% — ${msg}`);
  if (splashWindow && !splashWindow.isDestroyed())
    splashWindow.webContents.send('status', { msg, progress: pct });
}

// ── Spawn background process ───────────────────────────────────────────────
function run(name, cmd, args) {
  const p = spawn(cmd, args, { shell:true, detached:false, stdio:'ignore', windowsHide:true });
  p.on('error', e => console.log(`[${name}] error: ${e.message}`));
  p.on('exit',  c => console.log(`[${name}] exit: ${c}`));
  procs[name] = p;
}

// ── Find node.exe ──────────────────────────────────────────────────────────
function findNode() {
  const tries = [
    'node',
    path.join(process.env['ProgramFiles']  || 'C:\\Program Files', 'nodejs', 'node.exe'),
    path.join(process.env['LOCALAPPDATA']  || '', 'Programs', 'nodejs', 'node.exe'),
    path.join(process.env['USERPROFILE']   || '', 'AppData', 'Local', 'Programs', 'nodejs', 'node.exe'),
  ];
  for (const t of tries) {
    try { execSync(`"${t}" --version`, { stdio:'ignore', shell:true, timeout:3000 }); return t; }
    catch {}
  }
  return null;
}

// ── Service startup ────────────────────────────────────────────────────────
async function startServices() {
  // 1 ── Ollama
  status('Starting AI engine…', 10);
  if (!(await portOpen(OLLAMA_PORT))) {
    run('ollama', 'ollama', ['serve']);
    await waitPort(OLLAMA_PORT, 25000);
  }

  // 2 ── Docker / Open WebUI
  status('Waking up your assistant…', 30);
  if (!(await portOpen(WEBUI_PORT))) {
    run('webui', 'docker', ['start', 'open-webui']);
    status('Open WebUI loading (first boot ~2 min)…', 40);
    await waitPort(WEBUI_PORT, 150000);
  }

  // 3 ── NeuralBox Hub
  status('Starting NeuralBox portal…', 60);
  if (!(await portOpen(HUB_PORT))) {
    const hubJs = path.join(HUB_DIR, 'hub.js');
    if (fs.existsSync(hubJs)) {
      try {
        // Run hub inside Electron's Node.js — no child process needed
        require(hubJs);
      } catch (e) {
        const node = findNode();
        if (node) run('hub', node, [hubJs]);
      }
    }
    await waitPort(HUB_PORT, 15000);
  }

  // 4 ── OpenClaw (optional)
  status('Connecting AI agents…', 78);
  if (!(await portOpen(CLAW_PORT))) {
    const cfgPath = path.join(os.homedir(), '.openclaw', 'openclaw.json');
    if (fs.existsSync(cfgPath)) {
      const node = findNode();
      if (node) {
        try {
          const npmRoot = execSync(`"${node}" -e "console.log(require('path').join(process.env.APPDATA||'','..','..','..',process.platform==='win32'?'Roaming':'',process.platform==='win32'?'npm':''))"`,
            { shell:true, encoding:'utf8', timeout:3000 }).trim();
          const clawBin = path.join(process.env['APPDATA'] || '', 'npm', 'openclaw.cmd');
          if (fs.existsSync(clawBin)) run('openclaw', clawBin, ['gateway', '--config', cfgPath]);
        } catch {}
      }
    }
  }

  status('Almost ready…', 90);
  await waitPort(HUB_PORT, 8000);
  status('Welcome to your AI empire.', 100);
  await new Promise(r => setTimeout(r, 900));
}

// ── Build tray icon via hidden canvas window ───────────────────────────────
function buildIcon() {
  return new Promise(resolve => {
    const w = new BrowserWindow({
      show: false, width:64, height:64,
      webPreferences: { preload: path.join(__dirname,'preload.js'), contextIsolation:true }
    });
    ipcMain.once('icon-ready', (_, url) => { w.destroy(); resolve(nativeImage.createFromDataURL(url)); });
    w.loadFile(path.join(__dirname, 'create-icon.html'));
  });
}

// ── Windows ────────────────────────────────────────────────────────────────
function createSplash() {
  splashWindow = new BrowserWindow({
    width:480, height:300, frame:false, transparent:true,
    alwaysOnTop:true, resizable:false, center:true, skipTaskbar:true,
    icon: appIcon || undefined,
    webPreferences: { preload: path.join(__dirname,'preload.js'), contextIsolation:true }
  });
  splashWindow.loadFile(path.join(__dirname,'splash.html'));
}

function createMain() {
  mainWindow = new BrowserWindow({
    width:1300, height:880, minWidth:960, minHeight:640,
    show:false, autoHideMenuBar:true,
    title:'NeuralBox — Your Private AI Empire',
    icon: appIcon || undefined,
    webPreferences: { preload: path.join(__dirname,'preload.js'), contextIsolation:true, nodeIntegration:false }
  });

  mainWindow.loadURL(`http://localhost:${HUB_PORT}`);

  mainWindow.once('ready-to-show', () => {
    if (splashWindow && !splashWindow.isDestroyed()) { splashWindow.destroy(); splashWindow = null; }
    mainWindow.show();
    mainWindow.focus();
  });

  // Minimize to tray on close
  mainWindow.on('close', e => {
    if (!isQuitting) {
      e.preventDefault();
      mainWindow.hide();
      if (tray && process.platform === 'win32') {
        tray.displayBalloon({
          title:'NeuralBox is still running',
          content:'Your AI is running in the background. Right-click the tray icon to quit.',
          iconType:'info'
        });
      }
    }
  });

  mainWindow.on('closed', () => { mainWindow = null; });
}

// ── Tray ───────────────────────────────────────────────────────────────────
function buildTray() {
  tray = new Tray(appIcon);
  tray.setToolTip('NeuralBox — Your Private AI Empire');
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: '⚡  Open NeuralBox',  click: () => mainWindow ? (mainWindow.show(), mainWindow.focus()) : createMain() },
    { type: 'separator' },
    { label: '🔁  Restart Services', click: restartServices },
    { label: '🌐  Open WebUI Chat',  click: () => shell.openExternal('http://localhost:3000') },
    { label: '🤖  Clawbot Agent',   click: () => shell.openExternal('http://localhost:18789/webchat') },
    { type: 'separator' },
    { label: '✖   Quit NeuralBox',  click: () => { isQuitting = true; app.quit(); } }
  ]));
  tray.on('double-click', () => mainWindow ? (mainWindow.show(), mainWindow.focus()) : createMain());
}

// ── Restart all services ───────────────────────────────────────────────────
async function restartServices() {
  for (const p of Object.values(procs)) { try { p.kill(); } catch {} }
  Object.keys(procs).forEach(k => delete procs[k]);
  if (mainWindow) mainWindow.hide();
  createSplash();
  await startServices();
  if (mainWindow) { mainWindow.loadURL(`http://localhost:${HUB_PORT}`); mainWindow.show(); }
  else createMain();
  if (splashWindow && !splashWindow.isDestroyed()) { splashWindow.destroy(); splashWindow = null; }
}

// ── Boot ───────────────────────────────────────────────────────────────────
app.whenReady().then(async () => {
  appIcon = await buildIcon();
  createSplash();
  buildTray();
  await startServices();
  createMain();
});

app.on('before-quit', () => {
  isQuitting = true;
  for (const p of Object.values(procs)) { try { p.kill(); } catch {} }
});

// Keep alive in tray
app.on('window-all-closed', () => { /* intentionally empty — live in tray */ });
