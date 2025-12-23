import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

// CameraChip.qml
// A single camera bubble chip with ScreenShare-style visuals and hover popup.
// - Shows only when one or more apps are using the camera (PipeWire-based detection).
// - Sized to match other bar indicators (40 x Appearance.sizes.barHeight).
// - Uses a centered, anchored MaterialSymbol icon and a compact hover popup.
//
// Detection logic:
// - We scan Pipewire.linkGroups.values for groups where source.type === PwNodeType.VideoSource.
// - Prefer the target node (consumer app stream); fallback to the source node label.
// - If at least one such node is found, the camera chip is shown; otherwise hidden.

MouseArea {
    id: camChip
    hoverEnabled: true

    // Public API
    property bool vertical: false
    property color colBackground: Appearance.colors.colPrimary
    property color colText: Appearance.colors.colOnPrimary

    // Sizing consistent with ScreenShareIndicator
    implicitWidth: 40
    implicitHeight: Appearance.sizes.barHeight

    // Visibility behavior: poll periodically like the microphone indicator
    Component.onCompleted: updateVisibility()
    onVisibleChanged: updateVisibility()
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: updateVisibility()
    }

    function updateVisibility() {
        const active = camNodeCount() > 0;
        // Toggle the bubble's visibility
        camChip.visible = active;
        // Inform a parent bar container (if present) to adjust layout
        rootItem?.toggleVisible?.(active);
    }

    // Build a list of app nodes currently using the camera.
    // Rule: any PipeWire link group where source.type === PwNodeType.VideoSource.
    // Prefer the target node (app stream); fallback to source node otherwise.
    function cameraAppNodes() {
        const groups = (Pipewire.linkGroups && Pipewire.linkGroups.values) ? Pipewire.linkGroups.values : [];
        const results = [];
        const seen = {};

        for (let i = 0; i < groups.length; i++) {
            const g = groups[i];
            const src = g?.source;
            const tgt = g?.target;
            if (!src)
                continue;
            if (src.type !== PwNodeType.VideoSource)
                continue;

            const node = (tgt && (tgt.isStream === true || tgt.type === PwNodeType.VideoInStream)) ? tgt : src;
            if (!node)
                continue;

            const key = node.id !== undefined ? String(node.id) : (node.name || "");
            if (!key || seen[key])
                continue;
            seen[key] = true;

            results.push(node);
        }
        return results;
    }

    function camNodeCount() {
        return cameraAppNodes().length;
    }

    function firstCameraLabel() {
        const nodes = cameraAppNodes();
        if (nodes.length < 1)
            return "";
        const n = nodes[0];
        // Reuse Audio's helper when available; otherwise fallback to properties
        if (typeof Audio?.appNodeDisplayName === "function")
            return Audio.appNodeDisplayName(n);
        return n?.properties?.["application.name"] || n?.description || n?.name || Translation.tr("Unknown");
    }

    // Bubble background
    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.verysmall
        color: camChip.colBackground
    }

    // Centered icon (ScreenShare-style)
    MaterialSymbol {
        id: iconIndicator
        text: "videocam"
        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
        color: camChip.colText
        font.pixelSize: Appearance.font.pixelSize.huge
    }

    // Hover popup (styled like ScreenShareIndicator)
    StyledPopup {
        hoverTarget: camChip
        contentItem: ColumnLayout {
            anchors.centerIn: parent
            RowLayout {
                MaterialSymbol {
                    Layout.bottomMargin: 2
                    text: "videocam"
                }
                StyledText {
                    text: {
                        const count = camNodeCount();
                        const label = camChip.firstCameraLabel() || Translation.tr("%1 app%2").arg(count).arg(count === 1 ? "" : "s");
                        return Translation.tr("**%1** is using your camera").arg(label);
                    }
                    textFormat: Text.MarkdownText
                }
            }
        }
    }
}
