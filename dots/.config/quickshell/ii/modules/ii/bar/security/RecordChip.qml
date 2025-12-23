import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

// RecordChip.qml
// A single screen recording bubble chip with ScreenShare-style visuals and hover popup.
// - Shows only when Persistent.states.screenRecord.active is true.
// - Sized to match other bar indicators (40 x Appearance.sizes.barHeight).
// - Uses a centered, anchored MaterialSymbol icon and a compact hover popup.

MouseArea {
    id: recordChip
    hoverEnabled: true

    // Public API
    property bool vertical: false
    property color colBackground: Appearance.colors.colPrimary
    property color colText: Appearance.colors.colOnPrimary

    // Sizing consistent with ScreenShareIndicator
    implicitWidth: 40
    implicitHeight: Appearance.sizes.barHeight

    // Active state from Persistent
    readonly property bool activelyRecording: Persistent.states.screenRecord.active

    // Visibility behavior: update on startup and when active state changes
    Component.onCompleted: updateVisibility()
    onActivelyRecordingChanged: updateVisibility()

    function updateVisibility() {
        // Toggle the bubble's visibility
        recordChip.visible = recordChip.activelyRecording;
        // Also inform a parent bar container (if present) to adjust layout
        rootItem?.toggleVisible?.(recordChip.activelyRecording);
    }

    // Helpers
    function formatTime(totalSeconds) {
        let mins = Math.floor(totalSeconds / 60);
        let secs = totalSeconds % 60;
        return String(mins).padStart(2, "0") + ":" + String(secs).padStart(2, "0");
    }

    // Bubble background
    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.verysmall
        color: recordChip.colBackground
    }

    // Centered icon (ScreenShare-style)
    MaterialSymbol {
        id: iconIndicator
        text: "screen_record"
        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
        color: recordChip.colText
        font.pixelSize: Appearance.font.pixelSize.huge
    }

    // Hover popup (styled like ScreenShareIndicator)
    StyledPopup {
        hoverTarget: recordChip
        contentItem: ColumnLayout {
            anchors.centerIn: parent
            RowLayout {
                MaterialSymbol {
                    Layout.bottomMargin: 2
                    text: "screen_record"
                }
                StyledText {
                    text: Translation.tr("Recording...   %1").arg(formatTime(Persistent.states.screenRecord.seconds))
                }
            }
        }
    }
}
