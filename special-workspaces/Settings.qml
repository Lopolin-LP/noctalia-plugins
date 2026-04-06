import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string mainIcon: cfg.mainIcon ?? defaults.mainIcon
    property string expandDirection: cfg.expandDirection ?? defaults.expandDirection
    property bool   drawer: cfg.drawer ?? defaults.drawer
    property bool   hideEmpty: cfg.hideEmptyWorkspaces ?? defaults.hideEmptyWorkspaces

    property bool primaryShowPill: cfg.primaryShowPill ?? defaults.primaryShowPill
    property string primarySymbolColor: cfg.primarySymbolColor ?? defaults.primarySymbolColor
    property string primaryPillColor: cfg.primaryPillColor ?? defaults.primaryPillColor
    property real primarySize: cfg.primarySize ?? defaults.primarySize

    property bool secondaryShowPill: cfg.secondaryShowPill ?? defaults.secondaryShowPill
    property string secondarySymbolColor: cfg.secondarySymbolColor ?? defaults.secondarySymbolColor
    property string secondaryPillColor: cfg.secondaryPillColor ?? defaults.secondaryPillColor
    property real secondarySize: cfg.secondarySize ?? defaults.secondarySize
    property real borderRadius: cfg.borderRadius ?? defaults.borderRadius
    property string focusBorderColor: cfg.focusBorderColor ?? defaults.focusBorderColor
    property string panelBackgroundColor: cfg.panelBackgroundColor ?? defaults.panelBackgroundColor ?? "surface"
    property bool panelBackgroundEnabled: cfg.panelBackgroundEnabled ?? defaults.panelBackgroundEnabled ?? true

    readonly property string barPosition: Settings.getBarPositionForScreen()
    readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
    readonly property bool isPerpendicular: (isBarVertical && (root.expandDirection === "left" || root.expandDirection === "right")) ||
                                            (!isBarVertical && (root.expandDirection === "up" || root.expandDirection === "down"))

    // Local mutable copy for editing
    property var workspaces: []
    property int workspacesRevision: 0

    spacing: Style.marginL

    Component.onCompleted: {
        loadWorkspaces();
    }

    function loadWorkspaces() {
        var src = cfg.workspaces ?? defaults.workspaces;
        if (!src || !Array.isArray(src)) src = [];
        var copy = [];
        for (var i = 0; i < src.length; i++) {
            copy.push({ "name": src[i].name || "", "icon": src[i].icon || "star" });
        }
        workspaces = copy;
        workspacesRevision++;
    }

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("SpecialWorkspaces", "Cannot save settings: pluginApi is null");
            return;
        }

        var valid = [];
        for (var i = 0; i < workspaces.length; i++) {
            var name = workspaces[i].name.trim();
            if (name !== "") {
                valid.push({ "name": name, "icon": workspaces[i].icon || "star" });
            }
        }

        pluginApi.pluginSettings.mainIcon = root.mainIcon;
        pluginApi.pluginSettings.expandDirection = root.expandDirection;
        pluginApi.pluginSettings.drawer = root.drawer;
        pluginApi.pluginSettings.hideEmptyWorkspaces = root.hideEmpty;
        pluginApi.pluginSettings.primaryShowPill = root.primaryShowPill;
        pluginApi.pluginSettings.primarySymbolColor = root.primarySymbolColor;
        pluginApi.pluginSettings.primaryPillColor = root.primaryPillColor;
        pluginApi.pluginSettings.primarySize = root.primarySize;
        pluginApi.pluginSettings.secondaryShowPill = root.secondaryShowPill;
        pluginApi.pluginSettings.secondarySymbolColor = root.secondarySymbolColor;
        pluginApi.pluginSettings.secondaryPillColor = root.secondaryPillColor;
        pluginApi.pluginSettings.secondarySize = root.secondarySize;
        pluginApi.pluginSettings.borderRadius = root.borderRadius;
        pluginApi.pluginSettings.focusBorderColor = root.focusBorderColor;
        pluginApi.pluginSettings.panelBackgroundColor = root.panelBackgroundColor;
        pluginApi.pluginSettings.panelBackgroundEnabled = root.panelBackgroundEnabled;
        pluginApi.pluginSettings.workspaces = valid;
        pluginApi.saveSettings();
        Logger.i("SpecialWorkspaces", "Settings saved");
    }

    NText {
        text: pluginApi?.tr("settings.title")
        pointSize: Style.fontSizeL
        font.bold: true
    }

    NText {
        text: pluginApi?.tr("settings.description")
        color: Color.mOnSurfaceVariant
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }

    RowLayout {
        spacing: Style.marginM

        NIcon {
            Layout.alignment: Qt.AlignVCenter
            icon: root.mainIcon
            pointSize: Style.fontSizeXL
        }

        NTextInput {
            id: mainIconInput
            Layout.preferredWidth: 140
            label: pluginApi?.tr("settings.mainIcon.label")
            text: root.mainIcon
            onTextChanged: {
                if (text !== root.mainIcon) {
                    root.mainIcon = text;
                }
            }
        }

        NIconButton {
            icon: "search"
            tooltipText: pluginApi?.tr("settings.mainIcon.browseTooltip")
            onClicked: {
                mainIconPicker.open();
            }
        }
    }

    NIconPicker {
        id: mainIconPicker
        initialIcon: root.mainIcon
        onIconSelected: function (iconName) {
            root.mainIcon = iconName;
            mainIconInput.text = iconName;
        }
    }

    NToggle {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.drawer.label")
      description: pluginApi?.tr("settings.drawer.description")
      checked: root.drawer
      onToggled: checked => root.drawer = checked
    }

    NToggle {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.hideEmpty.label")
      checked: root.hideEmpty
      onToggled: checked => root.hideEmpty = checked
    }

    NComboBox {
        visible: root.drawer
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.expandDirection.label")
        description: pluginApi?.tr("settings.expandDirection.description")
        model: [
            { "key": "down", "name": pluginApi?.tr("settings.expandDirection.down") },
            { "key": "up", "name": pluginApi?.tr("settings.expandDirection.up") },
            { "key": "right", "name": pluginApi?.tr("settings.expandDirection.right") },
            { "key": "left", "name": pluginApi?.tr("settings.expandDirection.left") }
        ]
        currentKey: root.expandDirection
        onSelected: function (key) {
            root.expandDirection = key;
        }
        defaultValue: "down"
    }

    NToggle {
        visible: root.isPerpendicular
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.panelBackground.enabled.label")
        description: pluginApi?.tr("settings.panelBackground.enabled.description")
        checked: root.panelBackgroundEnabled
        onToggled: checked => { root.panelBackgroundEnabled = checked; }
        defaultValue: true
    }

    NColorChoice {
        visible: root.isPerpendicular && root.panelBackgroundEnabled
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.panelBackgroundColor.label")
        description: pluginApi?.tr("settings.panelBackgroundColor.description")
        currentKey: root.panelBackgroundColor
        onSelected: key => { root.panelBackgroundColor = key; }
        defaultValue: "surface"
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.borderRadius.label")
            description: pluginApi ? pluginApi.tr("settings.borderRadius.description").replace("%1", Math.round(root.borderRadius * 100)) : ""
        }

        NSlider {
            Layout.fillWidth: true
            from: 0
            to: 1.0
            stepSize: 0.05
            value: root.borderRadius
            onMoved: root.borderRadius = value
        }
    }

    NColorChoice {
        label: pluginApi?.tr("settings.focusBorderColor.label")
        description: pluginApi?.tr("settings.focusBorderColor.description")
        currentKey: root.focusBorderColor
        onSelected: key => { root.focusBorderColor = key; }
        defaultValue: "none"
    }

    // --- Primary Button ---

    NText {
        text: pluginApi?.tr("settings.primaryButton.title")
        pointSize: Style.fontSizeM
        font.bold: true
    }

    NToggle {
        label: pluginApi?.tr("settings.primaryButton.showPill.label")
        description: pluginApi?.tr("settings.primaryButton.showPill.description")
        checked: root.primaryShowPill
        onToggled: checked => { root.primaryShowPill = checked; }
        defaultValue: true
    }

    NColorChoice {
        label: pluginApi?.tr("settings.primaryButton.symbolColor.label")
        description: pluginApi?.tr("settings.primaryButton.symbolColor.description")
        currentKey: root.primarySymbolColor
        onSelected: key => { root.primarySymbolColor = key; }
        defaultValue: "none"
    }

    NColorChoice {
        label: pluginApi?.tr("settings.primaryButton.pillColor.label")
        description: pluginApi?.tr("settings.primaryButton.pillColor.description")
        currentKey: root.primaryPillColor
        onSelected: key => { root.primaryPillColor = key; }
        defaultValue: "none"
        visible: root.primaryShowPill
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.primaryButton.size.label")
            description: pluginApi ? pluginApi.tr("settings.primaryButton.size.description").replace("%1", Math.round(root.primarySize * 100)) : ""
        }

        NSlider {
            Layout.fillWidth: true
            from: 0.3
            to: 1.0
            stepSize: 0.05
            value: root.primarySize
            onMoved: root.primarySize = value
        }
    }

    // --- Secondary Buttons ---

    NText {
        text: pluginApi?.tr("settings.secondaryButtons.title")
        pointSize: Style.fontSizeM
        font.bold: true
    }

    NToggle {
        label: pluginApi?.tr("settings.secondaryButtons.showPill.label")
        description: pluginApi?.tr("settings.secondaryButtons.showPill.description")
        checked: root.secondaryShowPill
        onToggled: checked => { root.secondaryShowPill = checked; }
        defaultValue: true
    }

    NColorChoice {
        label: pluginApi?.tr("settings.secondaryButtons.symbolColor.label")
        description: pluginApi?.tr("settings.secondaryButtons.symbolColor.description")
        currentKey: root.secondarySymbolColor
        onSelected: key => { root.secondarySymbolColor = key; }
        defaultValue: "none"
    }

    NColorChoice {
        label: pluginApi?.tr("settings.secondaryButtons.pillColor.label")
        description: pluginApi?.tr("settings.secondaryButtons.pillColor.description")
        currentKey: root.secondaryPillColor
        onSelected: key => { root.secondaryPillColor = key; }
        defaultValue: "none"
        visible: root.secondaryShowPill
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.secondaryButtons.size.label")
            description: pluginApi ? pluginApi.tr("settings.secondaryButtons.size.description").replace("%1", Math.round(root.secondarySize * 100)) : ""
        }

        NSlider {
            Layout.fillWidth: true
            from: 0.3
            to: 1.0
            stepSize: 0.05
            value: root.secondarySize
            onMoved: root.secondarySize = value
        }
    }

    NDivider {
        Layout.fillWidth: true
    }

    // Workspace list
    Repeater {
        model: {
            void root.workspacesRevision;
            return root.workspaces.length;
        }

        delegate: RowLayout {
            id: wsRow
            required property int index

            Layout.fillWidth: true
            spacing: Style.marginM

            readonly property var ws: {
                void root.workspacesRevision;
                return index >= 0 && index < root.workspaces.length ? root.workspaces[index] : null;
            }

            NIcon {
                Layout.alignment: Qt.AlignVCenter
                icon: wsRow.ws ? wsRow.ws.icon : "star"
                pointSize: Style.fontSizeXL
            }

            NTextInput {
                Layout.fillWidth: true
                Layout.preferredWidth: 140
                placeholderText: pluginApi?.tr("settings.workspaces.namePlaceholder")
                text: wsRow.ws ? wsRow.ws.name : ""
                onTextChanged: {
                    if (wsRow.ws && text !== wsRow.ws.name) {
                        root.workspaces[wsRow.index].name = text;
                    }
                }
            }

            NTextInput {
                id: iconInput
                Layout.preferredWidth: 120
                placeholderText: pluginApi?.tr("settings.workspaces.iconPlaceholder")
                text: wsRow.ws ? wsRow.ws.icon : ""
                onTextChanged: {
                    if (wsRow.ws && text !== wsRow.ws.icon) {
                        root.workspaces[wsRow.index].icon = text;
                        root.workspacesRevision++;
                    }
                }

                // Re-sync text when icon is changed externally (e.g., via icon picker)
                Connections {
                    target: root
                    function onWorkspacesRevisionChanged() {
                        if (wsRow.ws && iconInput.text !== wsRow.ws.icon) {
                            iconInput.text = wsRow.ws.icon;
                        }
                    }
                }
            }

            NIconButton {
                icon: "search"
                tooltipText: pluginApi?.tr("settings.mainIcon.browseTooltip")
                onClicked: {
                    iconPicker.activeIndex = wsRow.index;
                    iconPicker.initialIcon = wsRow.ws ? wsRow.ws.icon : "star";
                    iconPicker.query = wsRow.ws ? wsRow.ws.icon : "";
                    iconPicker.open();
                }
            }

            NIconButton {
                icon: "trash"
                tooltipText: pluginApi?.tr("settings.workspaces.removeTooltip")
                onClicked: {
                    root.workspaces.splice(wsRow.index, 1);
                    root.workspacesRevision++;
                }
            }
        }
    }

    NIconPicker {
        id: iconPicker
        property int activeIndex: -1
        initialIcon: "star"
        onIconSelected: function (iconName) {
            if (activeIndex >= 0 && activeIndex < root.workspaces.length) {
                root.workspaces[activeIndex].icon = iconName;
                root.workspacesRevision++;
            }
        }
    }

    NButton {
        text: pluginApi?.tr("settings.workspaces.add")
        icon: "plus"
        onClicked: {
            root.workspaces.push({ "name": "", "icon": "star" });
            root.workspacesRevision++;
        }
    }
}
