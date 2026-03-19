import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI
import Quickshell.Hyprland
import Quickshell.Wayland

Item {
    id: root

    // --- Propriedades Obrigatórias do Painel (Injetadas pelo Noctalia) ---
    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true
    
    // Dimensões recomendadas adaptadas à escala da interface
    property real contentPreferredWidth: 840 * Style.uiScaleRatio
    property real contentPreferredHeight: Math.max(320 * Style.uiScaleRatio, (workspaceGrid.computedRows * workspaceGrid.cellHeight) + 100 * Style.uiScaleRatio)

    anchors.fill: parent

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors {
                fill: parent
                margins: Style.marginL
            }
            spacing: Style.marginL

            // --- Cabeçalho ---
            RowLayout {
                Layout.fillWidth: true
                NText {
                    text: "Workspace Overview"
                    pointSize: Style.fontSizeXL
                    font.weight: Font.Bold
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }
                NIconButton {
                    icon: "x"
                    onClicked: {
                        if (pluginApi) {
                            pluginApi.closePanel(pluginApi.panelOpenScreen)
                        }
                    }
                }
            }

            // --- Área de Workspaces (Grid) ---
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Color.mSurfaceVariant
                radius: Style.radiusL

                GridView {
                    id: workspaceGrid
                    anchors.centerIn: parent
                    
                    cellWidth: 260 * Style.uiScaleRatio
                    cellHeight: 180 * Style.uiScaleRatio
                    
                    // Calculamos a quantidade ideal de colunas e linhas para centralizar a grade
                    property int columns: Math.max(1, Math.floor((parent.width - Style.marginL * 2) / cellWidth))
                    property int computedRows: Math.max(1, Math.ceil(count / columns))
                    
                    width: Math.min(count * cellWidth, columns * cellWidth)
                    height: Math.min(computedRows * cellHeight, parent.height - Style.marginL * 2)
                    clip: true
                    
                    // Utilizando o model real do Hyprland fornecido pelo Quickshell
                    model: Hyprland.workspaces

                    // --- Componente de Workspace ---
                    delegate: DropArea {
                        width: workspaceGrid.cellWidth
                        height: workspaceGrid.cellHeight
                        
                        // O QML injeta as propriedades do modelo (id, name, etc) no escopo do delegate como modelData
                        property int targetWorkspaceId: typeof modelData !== "undefined" ? modelData.id : 0

                        // Ação ao soltar a janela neste workspace
                        onDropped: (drop) => {
                            if (drop.hasText && drop.text !== "") {
                                let windowData = JSON.parse(drop.text);
                                Logger.i("Overview", "Mover janela " + windowData.winId + " para o workspace " + targetWorkspaceId);
                                
                                // Comando do Hyprland via Quickshell
                                Hyprland.dispatch("movetoworkspacesilent " + targetWorkspaceId + ",address:" + windowData.winId);
                            }
                        }

                        Rectangle {
                            id: workspaceBg
                            anchors.fill: parent
                            anchors.margins: Style.marginM / 2
                            
                            // Highlight visual se for o workspace ativo ou se contém drag
                            readonly property bool isActiveWorkspace: typeof modelData !== "undefined" && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData.id
                            color: isActiveWorkspace ? Color.mPrimary : (parent.containsDrag ? Color.mSurfaceVariant : Color.mSurface)
                            opacity: parent.containsDrag ? 0.8 : 1.0
                            radius: Style.radiusM
                            border.color: isActiveWorkspace ? Color.mOnPrimary : Color.mOutline
                            border.width: parent.containsDrag ? 4 : 0

                            // MouseArea para clicar no workspace e alternar para ele
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (targetWorkspaceId !== undefined) {
                                        Hyprland.dispatch("workspace " + targetWorkspaceId);
                                        if (pluginApi) {
                                            pluginApi.closePanel(pluginApi.panelOpenScreen);
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Style.marginM / 2
                                spacing: Style.marginS

                                NText {
                                    text: typeof modelData !== "undefined" && modelData.name !== "" ? modelData.name : (typeof modelData !== "undefined" ? "Workspace " + modelData.id : "Loading...")
                                    font.weight: Font.Bold
                                    color: workspaceBg.isActiveWorkspace ? Color.mOnPrimary : Color.mOnSurface
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                // Lista de janelas ativas (Títulos)
                                Column {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 20 * Style.uiScaleRatio
                                    spacing: 1 * Style.uiScaleRatio
                                    clip: true
                                    
                                    Repeater {
                                        model: typeof modelData !== "undefined" && modelData.toplevels ? modelData.toplevels : null
                                        delegate: NText {
                                            width: 192 * Style.uiScaleRatio // Mesma largura do mini-monitor
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "• " + (typeof modelData !== "undefined" ? modelData.title : "App")
                                            pointSize: 8 * Style.uiScaleRatio
                                            elide: Text.ElideRight
                                            color: workspaceBg.isActiveWorkspace ? Color.mOnPrimary : Color.mOnSurfaceVariant
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                }

                                // Fundo do mini-monitor (Wallpaper real ou cor sólida)
                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                    Layout.preferredWidth: 192 * Style.uiScaleRatio
                                    Layout.preferredHeight: 108 * Style.uiScaleRatio
                                    color: Qt.rgba(0, 0, 0, 0.4)
                                    border.color: parent.parent.isActiveWorkspace ? Color.mOnPrimary : Color.mOutline
                                    border.width: 2 * Style.uiScaleRatio
                                    radius: Style.radiusS
                                    clip: true

                                    // Wallpaper
                                    Image {
                                        anchors.fill: parent
                                        source: typeof modelData !== "undefined" && typeof WallpaperService !== "undefined" ? WallpaperService.getWallpaper(modelData.monitor.name) : ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: source != ""
                                        opacity: 0.8
                                    }
                                    
                                    // As dimensões e posições reais vêm do monitor do workspace
                                    property var wsMonitor: typeof modelData !== "undefined" && modelData.monitor ? modelData.monitor : null
                                    property real monitorX: wsMonitor ? wsMonitor.x : 0
                                    property real monitorY: wsMonitor ? wsMonitor.y : 0
                                    property real monitorW: wsMonitor && wsMonitor.width > 0 ? wsMonitor.width : 1920
                                    property real monitorH: wsMonitor && wsMonitor.height > 0 ? wsMonitor.height : 1080
                                    property real scaleX: width / monitorW
                                    property real scaleY: height / monitorH

                                    Repeater {
                                        model: typeof modelData !== "undefined" && modelData.toplevels ? modelData.toplevels : null
                                        delegate: Rectangle {
                                            // Usando 'required property var modelData' força o QML a pegar o modelData do Repeater interno
                                            // escapando do sombreamento de escopo (shadowing) gerado pelo GridView externo.
                                            required property var modelData
                                            
                                            // As informações geométricas vêm do lastIpcObject associado à janela (inner modelData)
                                            property var ipcObj: typeof modelData !== "undefined" && modelData.lastIpcObject ? modelData.lastIpcObject : null
                                            property real winX: ipcObj && ipcObj.at ? ipcObj.at[0] : 0
                                            property real winY: ipcObj && ipcObj.at ? ipcObj.at[1] : 0
                                            property real winW: ipcObj && ipcObj.size ? ipcObj.size[0] : 0
                                            property real winH: ipcObj && ipcObj.size ? ipcObj.size[1] : 0
                                            
                                            // Posição relativa ao monitor
                                            x: (winX - parent.monitorX) * parent.scaleX
                                            y: (winY - parent.monitorY) * parent.scaleY
                                            width: Math.max(2, winW * parent.scaleX)
                                            height: Math.max(2, winH * parent.scaleY)
                                            
                                            // Ignorar janelas não mapeadas (escondidas)
                                            visible: typeof modelData !== "undefined" && typeof modelData.mapped !== "undefined" ? modelData.mapped : (ipcObj !== null && typeof ipcObj.mapped !== "undefined" ? ipcObj.mapped : true)
                                            
                                            color: Color.mPrimary
                                            border.color: Color.mBackground
                                            border.width: Math.max(1, 1 * Style.uiScaleRatio)
                                            radius: 2 * Style.uiScaleRatio
                                            clip: true
                                            
                                            ScreencopyView {
                                                anchors.fill: parent
                                                captureSource: modelData.wayland
                                                live: true
                                                paintCursor: true
                                                
                                                // Otimização: Só captura na resolução que estamos exibindo
                                                constraintSize: Qt.size(parent.width, parent.height)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
