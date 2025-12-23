pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.modules.common
import qs.modules.common.widgets
import qs.services

MouseArea {
    id: indicator
    hoverEnabled: true

    property bool vertical: false
    property color colBackground: Appearance.colors.colPrimary
    property color colText: Appearance.colors.colOnPrimary

    implicitWidth: 40
    implicitHeight: Appearance.sizes.barHeight

    Component.onCompleted: updateVisibility()
    onVisibleChanged: updateVisibility()
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: updateVisibility()
    }

    function updateVisibility() {
        rootItem?.toggleVisible?.(appCount() > 0);
    }

    function cameraAppNodes() {
        var groups = (Pipewire.linkGroups && Pipewire.linkGroups.values) ? Pipewire.linkGroups.values : [];
        var results = [];
        var seen = {};

        for (var i = 0; i < groups.length; i++) {
            var g = groups[i];
            var src = g?.source;
            var tgt = g?.target;

            if (!src)
                continue;
            if (src.type !== PwNodeType.VideoSource)
                continue;

            var node = (tgt && (tgt.isStream === true || tgt.type === PwNodeType.VideoInStream)) ? tgt : src;

            if (!node)
                continue;
            var key = node.id !== undefined ? String(node.id) : (node.name || "");
            if (!key || seen[key])
                continue;
            seen[key] = true;

            results.push(node);
        }
        return results;
    }

    function appCount() {
        return cameraAppNodes().length;
    }

    function firstFewApps(limit) {
        var nodes = cameraAppNodes();
        var list = [];
        var lim = Math.min(limit, nodes.length);
        for (var i = 0; i < lim; i++) {
            var n = nodes[i];

            var name = (typeof Audio?.appNodeDisplayName === "function") ? Audio.appNodeDisplayName(n) : (n.properties && n.properties["application.name"]) || n.description || n.name || Translation.tr("Unknown");
            list.push(name);
        }
        return list;
    }

    RippleButton {
        anchors.centerIn: parent
        implicitWidth: indicator.vertical ? 20 : parent.implicitWidth
        implicitHeight: indicator.vertical ? parent.implicitHeight : 20
        colBackgroundHover: "transparent"
        colRipple: "transparent"

        Loader {
            active: indicator.appCount() > 0
            sourceComponent: StyledPopup {
                hoverTarget: indicator
                contentItem: PopupContent {}
            }
        }
    }

    MaterialSymbol {
        id: iconIndicator
        z: 1
        text: "videocam"
        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
        color: Appearance.colors.colOnPrimary
        font.pixelSize: Appearance.font.pixelSize.huge
    }

    // Vertical content is unified with horizontal by using an anchored icon styled like ScreenShareIndicator

    component PopupContent: ColumnLayout {
        anchors.centerIn: parent

        RowLayout {
            MaterialSymbol {
                Layout.bottomMargin: 2
                text: "videocam"
            }
            StyledText {
                text: {
                    const names = indicator.firstFewApps(1);
                    const label = (names.length > 0) ? names[0] : Translation.tr("%1 app%2").arg(indicator.appCount()).arg(indicator.appCount() === 1 ? "" : "s");
                    return Translation.tr("**%1** is using your camera").arg(label);
                }
                textFormat: Text.MarkdownText
            }
        }

        Loader {
            active: indicator.appCount() > 0
            sourceComponent: ColumnLayout {
                spacing: 2

                StyledText {
                    text: Translation.tr("Apps using camera:")
                }

                Repeater {
                    model: indicator.firstFewApps(3)
                    delegate: RowLayout {
                        MaterialSymbol {
                            text: "app_shortcut"
                            Layout.bottomMargin: 2
                        }
                        StyledText {
                            text: modelData
                        }
                    }
                }

                Revealer {
                    reveal: indicator.appCount() > 3
                    RowLayout {
                        MaterialSymbol {
                            text: "more_horiz"
                            Layout.bottomMargin: 2
                        }
                        StyledText {
                            text: Translation.tr("+%1 more").arg(indicator.appCount() - 3)
                        }
                    }
                }
            }
        }
    }
}
