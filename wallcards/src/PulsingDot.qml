import QtQuick
import qs.Commons

Rectangle {
  id: root

  property bool pulsing: false
  property color dotColor: Color.mTertiary

  anchors.verticalCenter: parent.verticalCenter
  width: 6
  height: 6
  radius: 3
  color: pulsing ? dotColor : Qt.alpha(Color.mOnSurfaceVariant, 0.4)

  SequentialAnimation on opacity {
    running: root.pulsing
    loops: Animation.Infinite

    NumberAnimation {
      to: 0.4
      duration: 800
      easing.type: Easing.InOutSine
    }

    NumberAnimation {
      to: 1.0
      duration: 800
      easing.type: Easing.InOutSine
    }
  }
}
