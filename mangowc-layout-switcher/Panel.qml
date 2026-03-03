import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen currentScreen
  readonly property var geometryPlaceholder: panelContainer

  // ===== DATA & MAPPING =====

  readonly property string panelMonitor: {
    if (currentScreen && currentScreen.name) return currentScreen.name
    if (pluginApi && pluginApi.currentScreen && pluginApi.currentScreen.name) return pluginApi.currentScreen.name
    if (pluginApi && pluginApi.mainInstance && pluginApi.mainInstance.availableMonitors && pluginApi.mainInstance.availableMonitors.length > 0) {
      return pluginApi.mainInstance.availableMonitors[0]
    }
    return ""
  }
  
  readonly property var layouts: (pluginApi && pluginApi.mainInstance && pluginApi.mainInstance.availableLayouts) ? pluginApi.mainInstance.availableLayouts : []
  
  readonly property string activeLayout: {
    var layoutsDict = (pluginApi && pluginApi.mainInstance && pluginApi.mainInstance.monitorLayouts) ? pluginApi.mainInstance.monitorLayouts : {}
    return layoutsDict[root.selectedMonitors[0] || root.panelMonitor] || ""
  }

  // Matches BarWidget mapping and grouping
  readonly property var iconMap: ({
    "T":  "layout-sidebar",
    "M":  "rectangle",
    "S":  "carousel-horizontal",
    "G":  "layout-grid",
    "K":  "versions",
    "RT": "layout-sidebar-right",
    "CT": "layout-distribute-vertical",
    "TG": "layout-dashboard",
    "VT": "layout-rows",
    "VS": "carousel-vertical",
    "VG": "grid-dots",
    "VK": "chart-funnel"
  })

  property bool applyToAll: false
  property var selectedMonitors: []
  property real contentPreferredWidth: 360 * Style.uiScaleRatio 
  property real contentPreferredHeight: panelContent.implicitHeight + Style.margin2L

  function toggleMonitor(monitorName) {
    if (root.selectedMonitors.includes(monitorName)) {
      root.selectedMonitors = root.selectedMonitors.filter(m => m !== monitorName)
    } else {
      root.selectedMonitors = root.selectedMonitors.concat([monitorName])
    }
  }

  Component.onCompleted: {
    if (pluginApi && pluginApi.mainInstance) {
      pluginApi.mainInstance.refresh()
    }
  }

  // ===== UI =====

  Item {
    id: panelContainer
    anchors.fill: parent

    // Background Click Catcher (Closes Panel)
    MouseArea {
      anchors.fill: parent
      onClicked: {
        if (pluginApi) {
          pluginApi.closePanel()
        }
      }
    }

    // Panel Window Surface
    Rectangle {
      width: root.contentPreferredWidth
      height: root.contentPreferredHeight
      anchors.centerIn: parent
      
      color: Color.mSurface
      radius: Style.radiusL
      border.width: 1
      border.color: Color.mOutline

      // Inner Click Catcher (Prevents closing when clicking the panel itself)
      MouseArea {
        anchors.fill: parent
        onClicked: mouse => mouse.accepted = true 
      }

      ColumnLayout {
        id: panelContent
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        // Header
        NBox {
          Layout.fillWidth: true
          implicitHeight: headerRow.implicitHeight + Style.margin2M

          RowLayout {
            id: headerRow
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NIcon {
              icon: "layout-grid"
              pointSize: Style.fontSizeXL
              color: Color.mPrimary
            }

            NText {
              text: "Switch Layout"
              pointSize: Style.fontSizeXL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }
          }
        }

        // Options
        RowLayout {
          Layout.fillWidth: true

          NText {
            text: "Apply to all monitors"
            pointSize: Style.fontSizeL
            color: Color.mOnSurfaceVariant
            Layout.fillWidth: true
          }

          NToggle {
            checked: root.applyToAll
            onToggled: checked => {
              root.applyToAll = checked
              if (!checked && root.selectedMonitors.length === 0) {
                root.selectedMonitors = [root.panelMonitor]
              }
            }
          }
        }

        // Monitor Selector
        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginS
          
          // NEW: Reduce opacity and disable interactions when Apply to All is checked
          opacity: root.applyToAll ? 0.6 : 1.0
          enabled: !root.applyToAll

          NText {
            text: "Select monitors"
            pointSize: Style.fontSizeL
            color: Color.mOnSurfaceVariant
          }

          Flow {
            Layout.fillWidth: true
            spacing: Style.marginS

            Repeater {
              model: (pluginApi && pluginApi.mainInstance && pluginApi.mainInstance.availableMonitors) ? pluginApi.mainInstance.availableMonitors : []
              
              delegate: Rectangle {
                id: monitorBtn
                width: monitorContent.implicitWidth + (Style.marginM * 2)
                height: 36 * Style.uiScaleRatio
                
                // NEW: Show as selected if individually picked OR if Apply to All is active
                property bool isSelected: root.applyToAll || root.selectedMonitors.includes(modelData)
                
                property string currentLayout: {
                  var dict = (pluginApi && pluginApi.mainInstance && pluginApi.mainInstance.monitorLayouts) ? pluginApi.mainInstance.monitorLayouts : {}
                  return dict[modelData] || ""
                }
                
                color: isSelected ? Color.mPrimary : Color.mSurfaceVariant
                radius: Style.radiusM
                
                border.width: 2
                border.color: isSelected ? Color.mPrimary : Color.mOutline

                RowLayout {
                  id: monitorContent
                  anchors.centerIn: parent
                  spacing: Style.marginS

                  NIcon {
                    visible: isSelected
                    icon: "check"
                    pointSize: Style.fontSizeM
                    color: Color.mOnPrimary
                  }

                  NText {
                    text: modelData
                    color: isSelected ? Color.mOnPrimary : Color.mOnSurface
                    font.weight: Font.Medium
                    pointSize: Style.fontSizeS
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleMonitor(modelData)
                }
              }
            }
          }
        }

        NDivider { Layout.fillWidth: true }

        // Layout Grid
        Flow {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.marginS

          Repeater {
            model: root.layouts
            
            delegate: Rectangle {
              id: layoutBtn
              width: (root.contentPreferredWidth - Style.marginL * 2 - Style.marginS * 2) / 3
              height: 56 * Style.uiScaleRatio
              
              property bool isActive: {
                if (root.selectedMonitors.length === 0) {
                  return modelData.code === root.activeLayout
                } else if (root.selectedMonitors.length === 1) {
                  var mon = root.selectedMonitors[0]
                  var dict = (pluginApi && pluginApi.mainInstance && pluginApi.mainInstance.monitorLayouts) ? pluginApi.mainInstance.monitorLayouts : {}
                  var monLayout = dict[mon] || ""
                  return modelData.code === monLayout
                }
                return false
              }
              property bool isHovered: false

              color: isActive ? Color.mPrimary : Color.mSurfaceVariant
              radius: Style.radiusM

              Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: isHovered && !isActive ? Color.mHover : "transparent"
                opacity: isHovered && !isActive ? 0.2 : 0
              }

              ColumnLayout {
                anchors.centerIn: parent
                spacing: 2

                NIcon {
                  Layout.alignment: Qt.AlignHCenter
                  icon: root.iconMap[modelData.code] || "layout-board"
                  pointSize: Style.fontSizeL
                  color: layoutBtn.isActive ? Color.mOnPrimary : Color.mOnSurface
                }

                NText {
                  Layout.alignment: Qt.AlignHCenter
                  text: modelData.name
                  color: layoutBtn.isActive ? Color.mOnPrimary : Color.mOnSurface
                  font.weight: Font.Medium
                  pointSize: Style.fontSizeS
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: layoutBtn.isHovered = true
                onExited: layoutBtn.isHovered = false

                onClicked: {
                  if (root.applyToAll) {
                    pluginApi.mainInstance.setLayoutGlobally(modelData.code)
                  } else if (root.selectedMonitors.length > 0) {
                    root.selectedMonitors.forEach(m => {
                      pluginApi.mainInstance.setLayout(m, modelData.code)
                    })
                  } else {
                    pluginApi.mainInstance.setLayout(root.panelMonitor, modelData.code)
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
