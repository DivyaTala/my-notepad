// My Notepad - desktop window (Electron).
// Shows ../index.html in its own window with the Windows 11 Mica material behind it.
const { app, BrowserWindow, Menu, shell, ipcMain, nativeTheme, screen } = require('electron');
const path = require('path');
const fs = require('fs');
const { fileURLToPath, pathToFileURL } = require('url');

const root = path.join(__dirname, '..');
const indexFile = path.join(root, 'index.html');
const indexUrl = pathToFileURL(indexFile).href;

app.setName('My Notepad');
// notes, to-dos and settings live here (set MYNOTEPAD_DATA to use a different folder)
app.setPath('userData', process.env.MYNOTEPAD_DATA || path.join(app.getPath('appData'), 'MyNotepad'));
app.setAppUserModelId('MyNotepad.App');

let win = null;
const stateFile = () => path.join(app.getPath('userData'), 'window.json');
function loadState() { try { return JSON.parse(fs.readFileSync(stateFile(), 'utf8')); } catch { return {}; } }
function saveState() {
  if (!win || win.isDestroyed()) return;
  try { fs.writeFileSync(stateFile(), JSON.stringify({ bounds: win.getNormalBounds(), maximized: win.isMaximized() })); } catch {}
}

function createWindow() {
  const st = loadState();
  win = new BrowserWindow({
    width: 1280, height: 820, ...(st.bounds || {}),
    minWidth: 820, minHeight: 560,
    title: 'My Notepad',
    icon: path.join(root, 'icon.ico'),
    backgroundMaterial: 'mica',      // Windows 11 22H2 or newer; ignored elsewhere
    backgroundColor: '#00000000',    // let the material show wherever the page is see-through
    autoHideMenuBar: true,
    show: false,
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, nodeIntegration: false, sandbox: true, spellcheck: true },
  });
  if (st.maximized) win.maximize();
  win.loadFile(indexFile);
  win.once('ready-to-show', () => win.show());
  win.on('close', saveState);
  for (const ev of ['move', 'resize', 'maximize', 'unmaximize', 'enter-full-screen', 'leave-full-screen']) win.on(ev, sendBackdrop);
  win.on('focus', () => { wallpaper = null; sendBackdrop(); });

  // Links open in the normal browser, never inside the notepad window
  const external = url => { if (/^(https?:|mailto:)/i.test(url)) shell.openExternal(url); };
  win.webContents.setWindowOpenHandler(({ url }) => { external(url); return { action: 'deny' }; });
  win.webContents.on('will-navigate', (e, url) => { if (!url.startsWith(indexUrl)) { e.preventDefault(); external(url); } });

  // The window and taskbar icon follow the app's colour theme (the page swaps its icon)
  win.webContents.on('page-favicon-updated', (_e, icons) => {
    try { const f = icons.find(u => u.startsWith('file:')); if (f) win.setIcon(fileURLToPath(f)); } catch {}
  });
}

// Backdrop. Windows only draws its Mica material when the system allows it, and on many PCs it falls back to a flat colour.
// So the app draws the same look itself: the desktop wallpaper, heavily blurred and tinted, lined up with the screen
// so it stays put while the window moves. The page does the drawing; this just tells it where things are.
function wallpaperUrl() {
  try {
    const src = path.join(app.getPath('appData'), 'Microsoft', 'Windows', 'Themes', 'TranscodedWallpaper');
    const stat = fs.statSync(src);
    const copy = path.join(app.getPath('userData'), 'wallpaper.jpg'); // a copy with a file extension the page can load
    let fresh = false;
    try { fresh = fs.statSync(copy).mtimeMs >= stat.mtimeMs; } catch {}
    if (!fresh) fs.copyFileSync(src, copy);
    return pathToFileURL(copy).href + '?v=' + Math.round(stat.mtimeMs);
  } catch { return ''; } // no picture wallpaper: the page just uses its normal colours
}
// The wallpaper is looked up when the window opens or is focused (it may have changed), never while dragging,
// and position updates are sent at most once per screen frame.
let wallpaper = null, backdropTimer = null;
function sendBackdrop() {
  if (backdropTimer) return;
  backdropTimer = setTimeout(() => {
    backdropTimer = null;
    if (!win || win.isDestroyed()) return;
    if (wallpaper === null) wallpaper = wallpaperUrl();
    const c = win.getContentBounds(), d = screen.getDisplayMatching(win.getBounds()).bounds;
    win.webContents.send('backdrop', { url: wallpaper, x: c.x - d.x, y: c.y - d.y, w: d.width, h: d.height });
  }, 16);
}
ipcMain.on('backdrop-ready', sendBackdrop);

// Light or dark Mica to match the app's own light/dark switch
ipcMain.on('set-mode', (_e, mode) => { nativeTheme.themeSource = mode === 'dark' ? 'dark' : 'light'; });

if (!app.requestSingleInstanceLock()) app.quit();
else {
  app.on('second-instance', () => { if (win) { if (win.isMinimized()) win.restore(); win.focus(); } });
  app.whenReady().then(() => { Menu.setApplicationMenu(null); createWindow(); });
  app.on('window-all-closed', () => app.quit());
}
