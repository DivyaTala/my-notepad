// Runs before the page loads. Gives the page a few small, safe hooks into the desktop window.
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('desktopApp', {
  // light or dark, so the window frame and material match the app
  setMode: mode => ipcRenderer.send('set-mode', mode === 'dark' ? 'dark' : 'light'),
  // the backdrop: where the desktop wallpaper is and where this window sits on the screen
  onBackdrop: callback => ipcRenderer.on('backdrop', (_event, data) => callback(data)),
  backdropReady: () => ipcRenderer.send('backdrop-ready'),
});
