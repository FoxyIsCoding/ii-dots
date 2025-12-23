import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// ShareChip.qml
// A single screen share bubble chip with ScreenShare-style visuals and hover popup.
// - Shows only when the existing screenshare state file indicates activity (not "none").
// - Runs the configured screenshare state script in a background Process.
// - Sized to match other bar indicators (40 x Appearance.sizes.barHeight).
// - Uses a centered, anchored MaterialSymbol icon and a compact hover popup.

MouseArea {
    id: shareChip
    hoverEnabled: true

    // Public API
    property bool vertical: false
    property color colBackground: Appearance.colors.colPrimary
    property color colText: Appearance.colors.colOnPrimary

    // Sizing consistent with ScreenShareIndicator
    implicitWidth: 40
    implicitHeight: Appearance.sizes.barHeight

    // Screensharing active state and label (app name or description)
    property bool activelyScreenSharing: false
    property string screenshareLabel: ""

    // Run the screen share detection script continuously (like ScreenShareIndicator)
    Process {
        id: screenShareProc
        running: true
        command: ["bash", "-c", Directories.screenshareStateScript]
    }

    // Watch the state file and update chip visibility
    FileView {
        id: stateFile
        path: Directories.screenshareStatePath
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: {
            const content = (stateFile.text() ?? "").trim();
            const lower = content.toLowerCase();
            shareChip.activelyScreenSharing = !(lower.length === 0 || lower.includes("none"));
            shareChip.screenshareLabel = content;
            shareChip.visible = shareChip.activelyScreenSharing;
            // Inform parent bar container (if present) to adjust layout
            rootItem?.toggleVisible?.(shareChip.activelyScreenSharing);
        }
    }

    // Bubble background
    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.verysmall
        color: shareChip.colBackground
    }

    // Centered icon (ScreenShare-style)
    MaterialSymbol {
        id: iconIndicator
        text: "cast"
        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
        color: shareChip.colText
        font.pixelSize: Appearance.font.pixelSize.huge
    }

    // Hover popup (styled like ScreenShareIndicator)
    StyledPopup {
        hoverTarget: shareChip
        contentItem: ColumnLayout {
            anchors.centerIn: parent
            RowLayout {
                MaterialSymbol {
                    Layout.bottomMargin: 2
                    text: "cast"
                }
                StyledText {
                    text: {
                        const raw = (shareChip.screenshareLabel ?? "").trim();
                        const label = raw.length > 0 ? raw : Translation.tr("Unknown");
                        return Translation.tr("**%1** is using your screen").arg(label);
                    }
                    textFormat: Text.MarkdownText
                }
            }
        }
    }
}
