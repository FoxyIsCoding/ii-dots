import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

// MicChip.qml
// A single microphone bubble chip with ScreenShare-style visuals and hover popup.
// - Shows only when one or more apps are using the microphone.
// - Sized to match other bar indicators (40 x barHeight).
// - Uses a centered, anchored MaterialSymbol icon and a compact hover popup.

MouseArea {
    id: micChip
    hoverEnabled: true

    // Public API
    property bool vertical: false
    property color colBackground: Appearance.colors.colPrimary
    property color colText: Appearance.colors.colOnPrimary

    // Sizing consistent with ScreenShareIndicator
    implicitWidth: 40
    implicitHeight: Appearance.sizes.barHeight

    // Visibility behavior: poll periodically like MicIndicator
    Component.onCompleted: updateVisibility()
    onVisibleChanged: updateVisibility()
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: updateVisibility()
    }

    function updateVisibility() {
        const active = (Audio.inputAppNodes?.length ?? 0) > 0;
        // Toggle the bubble's visibility
        micChip.visible = active;
        // Also inform a parent bar container (if present) to adjust layout
        rootItem?.toggleVisible?.(active);
    }

    // Helpers
    function appCount() {
        return Audio.inputAppNodes?.length ?? 0;
    }
    function firstAppName() {
        const nodes = Audio.inputAppNodes ?? [];
        return nodes.length > 0 ? Audio.appNodeDisplayName(nodes[0]) : "";
    }

    // Bubble background
    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.verysmall
        color: micChip.colBackground
    }

    // Centered icon (ScreenShare-style)
    MaterialSymbol {
        id: iconIndicator
        text: "mic"
        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
        color: micChip.colText
        font.pixelSize: Appearance.font.pixelSize.huge
    }

    // Hover popup (styled like ScreenShareIndicator)
    StyledPopup {
        hoverTarget: micChip
        contentItem: ColumnLayout {
            anchors.centerIn: parent
            RowLayout {
                MaterialSymbol {
                    Layout.bottomMargin: 2
                    text: "mic"
                }
                StyledText {
                    text: {
                        const count = micChip.appCount();
                        const label = micChip.firstAppName() || Translation.tr("%1 app%2").arg(count).arg(count === 1 ? "" : "s");
                        return Translation.tr("**%1** is using your microphone").arg(label);
                    }
                    textFormat: Text.MarkdownText
                }
            }
        }
    }
}
