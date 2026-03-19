import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
    id: root
    property var pluginApi: null
    property var screen: null

    // Garante que o widget ocupe espaço na barra
    implicitWidth: Style.baseWidgetSize
    implicitHeight: Style.baseWidgetSize
    
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight

    // Utilizamos NIcon em vez de NIconButton para evitar o fundo em círculo com cores invertidas
    NIcon {
        id: widgetIcon
        anchors.centerIn: parent
        icon: "layout-dashboard"
        // Cor padrão do ícone: branca/cinza claro, como os demais. 
        // Adicionamos cor de hover se o mouse estiver em cima.
        color: mouseArea.containsMouse ? Color.mPrimary : Color.mOnSurface
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            if (pluginApi) {
                pluginApi.openPanel(root.screen, root)
            }
        }
    }
}
