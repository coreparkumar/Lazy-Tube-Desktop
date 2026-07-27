const { contextBridge } = require("electron");
contextBridge.exposeInMainWorld("electronAPI", {
  // Reserved for future IPC needs
  platform: process.platform,
});