import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true
    
    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    readonly property string expandDirection: cfg.expandDirection ?? defaults.expandDirection
    readonly property bool isVertical: expandDirection === "up" || expandDirection === "down"

    // Secondary button settings
    readonly property bool secShowPill: cfg.secondaryShowPill ?? defaults.secondaryShowPill
    readonly property string secSymbolColor: cfg.secondarySymbolColor ?? defaults.secondarySymbolColor
    readonly property string secPillColor: cfg.secondaryPillColor ?? defaults.secondaryPillColor
    readonly property real secondarySize: cfg.secondarySize ?? defaults.secondarySize

    readonly property real borderRadius: cfg.borderRadius ?? defaults.borderRadius
    readonly property string focusBorderColor: cfg.focusBorderColor ?? defaults.focusBorderColor
    readonly property string panelBackgroundColor: cfg.panelBackgroundColor ?? defaults.panelBackgroundColor ?? "surface"
    readonly property bool panelBackgroundEnabled: cfg.panelBackgroundEnabled ?? defaults.panelBackgroundEnabled ?? true

    readonly property bool showBackground: panelBackgroundEnabled && panelBackgroundColor !== "none"

    // Visibility settings
    readonly property bool hideEmpty: cfg.hideEmptyWorkspaces ?? defaults.hideEmptyWorkspaces

    // Reusing the same pill size math using the screen the panel is attached to
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(pluginApi?.panelOpenScreen?.name)
    readonly property real secPillSize: Math.round(capsuleHeight * secondarySize / 2) * 2
    readonly property real secIconSize: Style.toOdd(secPillSize * 0.55)
    readonly property real pillSpacing: Style.marginXS

    readonly property var configuredWorkspaces: {
        var list = cfg.workspaces ?? defaults.workspaces;
        if (!list || !Array.isArray(list)) list = defaults.workspaces || [];
        var result = [];
        for (var i = 0; i < list.length; i++) {
            result.push({
                "name": "special:" + list[i].name,
                "shortName": list[i].name,
                "icon": list[i].icon
            });
        }
        return result;
    }

    readonly property var activeWorkspaceNames: pluginApi?.mainInstance?.activeWorkspaceNames || ({})
    readonly property string internalActiveSpecial: pluginApi?.mainInstance?.activeSpecialByMonitor?.[pluginApi?.panelOpenScreen?.name] ?? ""

    readonly property int visibleWorkspacesCount: {
        if (hideEmpty) {
            var count = 0;
            for (var i = 0; i < configuredWorkspaces.length; i++) {
                if (activeWorkspaceNames[configuredWorkspaces[i].name]) count++;
            }
            return count;
        }
        return configuredWorkspaces.length;
    }

    // Panel size calculation based on how many pills are visible
    readonly property real fullSize: {
        return visibleWorkspacesCount > 0 
            ? secPillSize * visibleWorkspacesCount + pillSpacing * Math.max(0, visibleWorkspacesCount - 1)
            : 0;
    }

    property real contentPreferredWidth: isVertical ? secPillSize + Style.marginS * 2 : fullSize + Style.marginS * 2
    property real contentPreferredHeight: isVertical ? fullSize + Style.marginS * 2 : secPillSize + Style.marginS * 2

    anchors.fill: parent

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        Rectangle {
            anchors.centerIn: parent
            width: root.contentPreferredWidth
            height: root.contentPreferredHeight
            color: root.showBackground ? Color.resolveColorKey(root.panelBackgroundColor) : "transparent"
            radius: Style.radiusL
            border.color: root.showBackground ? Color.mOutline : "transparent"
            border.width: root.showBackground ? Style.borderS : 0
            
            // Render either row or column based on direction
            RowLayout {
                visible: !root.isVertical
                anchors.centerIn: parent
                spacing: root.pillSpacing
                layoutDirection: root.expandDirection === "left" ? Qt.RightToLeft : Qt.LeftToRight

                Repeater {
                    model: root.configuredWorkspaces
                    WorkspacePill {
                        visible: (!root.hideEmpty || root.activeWorkspaceNames[modelData.name] === true)
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            ColumnLayout {
                visible: root.isVertical
                anchors.centerIn: parent
                spacing: root.pillSpacing

                Repeater {
                    model: root.configuredWorkspaces
                    WorkspacePill {
                        visible: (!root.hideEmpty || root.activeWorkspaceNames[modelData.name] === true)
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }

    component WorkspacePill: Rectangle {
        id: wsPill
        required property var modelData

        implicitWidth: root.secPillSize
        implicitHeight: root.secPillSize
        radius: root.secPillSize / 2 * root.borderRadius
        color: {
            if (wsPillMouse.containsMouse) return root.secShowPill ? Color.mHover : Color.mTertiary;
            if (!root.secShowPill || root.secPillColor === "none") return "transparent";
            return Color.resolveColorKey(root.secPillColor);
        }

        readonly property bool isActive: root.activeWorkspaceNames[modelData.name] === true
        readonly property bool isFocused: root.internalActiveSpecial === modelData.name

        opacity: isActive ? 1.0 : 0.2
        border.color: {
            if (!isFocused) return "transparent";
            if (root.focusBorderColor === "none") return "transparent";
            if (root.focusBorderColor !== "") return Color.resolveColorKey(root.focusBorderColor);
            return root.secShowPill ? Color.mOnPrimary : Color.mPrimary;
        }
        border.width: 2

        Behavior on color { ColorAnimation { duration: Style.animationFast } }

        NIcon {
            icon: wsPill.modelData.icon
            pointSize: root.secIconSize
            applyUiScale: false
            color: {
                if (wsPillMouse.containsMouse) return root.secShowPill ? Color.mOnHover : Color.mOnTertiary;
                if (root.secSymbolColor !== "none") return Color.resolveColorKey(root.secSymbolColor);
                return (root.secShowPill && root.secPillColor !== "none") ? Color.resolveOnColorKey(root.secPillColor) : Color.mOnSurface;
            }
            anchors.centerIn: parent
        }

        MouseArea {
            id: wsPillMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: function (mouse) {
                Hyprland.dispatch(`togglespecialworkspace ${wsPill.modelData.shortName}`);
                if (pluginApi) pluginApi.closePanel(pluginApi.panelOpenScreen);
            }
        }

        Behavior on opacity { NumberAnimation { duration: Style.animationFast } }
        Behavior on border.color { ColorAnimation { duration: Style.animationFast } }
    }
}
