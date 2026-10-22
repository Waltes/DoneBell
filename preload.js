const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('api', {
  getState: () => ipcRenderer.invoke('get-state'),
  setState: (at) => ipcRenderer.invoke('set-state', at),
  getConfig: () => ipcRenderer.invoke('get-config'),
  setConfig: (c) => ipcRenderer.invoke('set-config', c),
  setPos: (pos) => ipcRenderer.invoke('set-pos', pos),
  setView: (settings) => ipcRenderer.invoke('set-view', settings),
  previewSound: (file) => ipcRenderer.send('preview-sound', file),
  close: () => ipcRenderer.send('close')
});
