pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.modules.common
import qs.modules.common.widgets
import qs.services

// SecurityComponent
// A merged privacy indicator that shows microphone, camera, screen recording, and screen sharing.
// - Hides entirely when none are active.
// - Uses ScreenShare-style visuals (anchored, centered, huge icons; compact hover info).
MouseArea {
    id: indicator
    hoverEnabled: true

    // Public API
    property bool vertical: false
    property color colBackground: "transparent"
    property color colText: Appearance.colors.colOnPrimary

    // Sizing consistent with ScreenShareIndicator to avoid wrapping
    implicitWidth: 40
    implicitHeight: Appearance.sizes.barHeight

    // States
    property bool micActive: false
    property var cameraNodes: []           // list<PwNode> representing apps using camera
    property bool recordingActive: Persistent.states.screenRecord.active
    property bool screenshareActive: false
    property string screenshareLabel: ""

    // Derived
    readonly property bool cameraActive: cameraNodes.length > 0
    readonly property bool anyActive: micActive || cameraActive || recordingActive || screenshareActive

    // Visibility behavior like other bar indicators
    Component.onCompleted: updateStates()
    onAnyActiveChanged: rootItem?.toggleVisible?.(anyActive)

    // Periodically recompute states
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: updateStates()
    }

    // Reuse your existing screen share script + state watching
    Process {
        id: screenshareProc
        running: true
        command: ["bash", "-c", Directories.screenshareStateScript]
    }
    FileView {
        id: screenshareStateFile
        path: Directories.screenshareStatePath
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: {
            const content = (screenshareStateFile.text() ?? "").trim();
            const lower = content.toLowerCase();
            indicator.screenshareActive = !(lower.length === 0 || lower.includes("none"));
            indicator.screenshareLabel = content;
            rootItem?.toggleVisible?.(indicator.anyActive);
        }
    }

    function updateStates() {
        // Mic: same logic as MicIndicator
        indicator.micActive = ((Audio.inputAppNodes?.length ?? 0) > 0);

        // Camera: via PipeWire link groups
        indicator.cameraNodes = cameraAppNodes();

        // recordingActive is bound to Persistent.states.screenRecord.active
        rootItem?.toggleVisible?.(indicator.anyActive);
    }

    // Build a list of app nodes currently using the camera.
    // Rule: any PipeWire link group where source.type === PwNodeType.VideoSource.
    // Prefer the target node (app stream), fall back to source node otherwise.
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

    function displayNameForNode(node) {
        if (typeof Audio?.appNodeDisplayName === "function") {
            return Audio.appNodeDisplayName(node);
        }
        return node?.properties?.["application.name"] || node?.description || node?.name || Translation.tr("Unknown");
    }
    function firstCameraLabel() {
        return cameraNodes.length > 0 ? displayNameForNode(cameraNodes[0]) : "";
    }

    // Grouped, linked icons in a single pill bubble (like before)
    // Shows all active indicators within one rounded rectangle, no separate square chips
    Item {
        anchors.fill: parent

        // Background pill
        Rectangle {
            id: pill
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                margins: 0
            }
            color: Appearance.colors.colPrimary
            radius: Appearance.rounding.verysmall
            visible: indicator.anyActive
        }

        // Centered row of active icons
        RowLayout {
            id: groupedIcons
            anchors.centerIn: parent
            spacing: 8

            Loader {
                active: indicator.micActive
                source: Qt.resolvedUrl("security/MicChip.qml")
            }
            Loader {
                active: indicator.cameraActive
                source: Qt.resolvedUrl("security/CameraChip.qml")
            }
            Loader {
                active: indicator.recordingActive
                source: Qt.resolvedUrl("security/RecordChip.qml")
            }
            Loader {
                active: indicator.screenshareActive
                source: Qt.resolvedUrl("security/ShareChip.qml")
            }
        }

        // Hover popup styled like ScreenShare: concise, single bubble
        StyledPopup {
            hoverTarget: pill
            contentItem: ColumnLayout {
                anchors.centerIn: parent
                spacing: 4

                Loader {
                    active: indicator.micActive
                    sourceComponent: RowLayout {
                        MaterialSymbol {
                            Layout.bottomMargin: 2
                            text: "mic"
                        }
                        StyledText {
                            text: {
                                const nodes = Audio.inputAppNodes ?? [];
                                const label = nodes.length > 0 ? Audio.appNodeDisplayName(nodes[0]) : Translation.tr("%1 app%2").arg(nodes.length).arg(nodes.length === 1 ? "" : "s");
                                return Translation.tr("**%1** is using your microphone").arg(label);
                            }
                            textFormat: Text.MarkdownText
                        }
                    }
                }
                Loader {
                    active: indicator.cameraActive
                    sourceComponent: RowLayout {
                        MaterialSymbol {
                            Layout.bottomMargin: 2
                            text: "videocam"
                        }
                        StyledText {
                            text: {
                                const label = indicator.firstCameraLabel() || Translation.tr("%1 app%2").arg(indicator.cameraNodes.length).arg(indicator.cameraNodes.length === 1 ? "" : "s");
                                return Translation.tr("**%1** is using your camera").arg(label);
                            }
                            textFormat: Text.MarkdownText
                        }
                    }
                }
                Loader {
                    active: indicator.recordingActive
                    sourceComponent: RowLayout {
                        function formatTime(totalSeconds) {
                            const mins = Math.floor(totalSeconds / 60);
                            const secs = totalSeconds % 60;
                            return String(mins).padStart(2, "0") + ":" + String(secs).padStart(2, "0");
                        }
                        MaterialSymbol {
                            Layout.bottomMargin: 2
                            text: "screen_record"
                        }
                        StyledText {
                            text: Translation.tr("Recording...   %1").arg(formatTime(Persistent.states.screenRecord.seconds))
                        }
                    }
                }
                Loader {
                    active: indicator.screenshareActive
                    sourceComponent: RowLayout {
                        MaterialSymbol {
                            Layout.bottomMargin: 2
                            text: "cast"
                        }
                        StyledText {
                            text: {
                                const raw = (indicator.screenshareLabel ?? "").trim();
                                const label = raw.length > 0 ? raw : Translation.tr("Unknown");
                                return Translation.tr("**%1** is using your screen").arg(label);
                            }
                            textFormat: Text.MarkdownText
                        }
                    }
                }
            }
        }
    }

    // Per-chip popups implemented above; no global hover popup needed here
}
