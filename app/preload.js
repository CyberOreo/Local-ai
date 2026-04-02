'use strict';
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  onStatus: (cb) => ipcRenderer.on('status', (_, data) => cb(data)),
  sendIcon: (dataUrl) => ipcRenderer.send('icon-ready', dataUrl)
});
