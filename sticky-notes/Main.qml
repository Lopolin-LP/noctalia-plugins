import QtQuick
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var pluginApi: null

  function withCurrentScreen(callback) {
    if (!pluginApi) {
      Logger.w("StickyNotes", "Plugin API not available for IPC request");
      return;
    }

    pluginApi.withCurrentScreen(function(screen) {
      if (!screen) {
        Logger.w("StickyNotes", "No active screen available for IPC request");
        return;
      }

      callback(screen);
    });
  }

  IpcHandler {
    target: "plugin:sticky-notes"

    function toggle() {
      root.withCurrentScreen(function(screen) {
        root.pluginApi.togglePanel(screen);
      });
    }
  }
}
