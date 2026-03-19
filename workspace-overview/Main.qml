import QtQuick
import Quickshell.Io
import qs.Commons

Item {
    id: root
    // O objectName é CRUCIAL para que o IPC o encontre
    objectName: "main" 
    
    property var pluginApi: null

    IpcHandler {
        target: "plugin:workspace-overview-plugin"

        function toggle() {
            root.showOverview();
        }
    }

    // Esta função será exposta
    function showOverview() {
        console.log("-> Recebido comando para abrir o Overview");
        if (pluginApi) {
            pluginApi.withCurrentScreen(screen => {
                pluginApi.togglePanel(screen);
            });
        }
    }

    Component.onCompleted: {
        console.log("-> [Main] Workspace Overview está pronto e ouvindo.");
    }
}
