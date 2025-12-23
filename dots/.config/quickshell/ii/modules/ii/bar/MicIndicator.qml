import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

MouseArea {
    id: indicator
    hoverEnabled: true

    property bool vertical: false
    property color colBackground: Appearance.colors.colPrimary
    property color colText: Appearance.colors.colOnPrimary

    Component.onCompleted: updateVisibility()
    onVisibleChanged: updateVisibility()
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: updateVisibility()
    }

    function updateVisibility() {
        rootItem?.toggleVisible?.((Audio.inputAppNodes?.length ?? 0) > 0);
    }

    implicitWidth: 40
    implicitHeight: Appearance.sizes.barHeight

    function appCount() {
        return Audio.inputAppNodes?.length ?? 0;
    }

    function firstFewApps(limit) {
        const nodes = Audio.inputAppNodes ?? [];
        return nodes.slice(0, limit).map(n => Audio.appNodeDisplayName(n));
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
        text: "mic"
        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
        color: Appearance.colors.colOnPrimary
        font.pixelSize: Appearance.font.pixelSize.huge
    }

    component PopupContent: ColumnLayout {
        anchors.centerIn: parent
        RowLayout {
            MaterialSymbol {
                Layout.bottomMargin: 2
                text: "mic"
            }
            StyledText {
                text: {
                    const names = indicator.firstFewApps(1);
                    const label = (names.length > 0) ? names[0] : Translation.tr("%1 app%2").arg(indicator.appCount()).arg(indicator.appCount() === 1 ? "" : "s");
                    return Translation.tr("**%1** is using your microphone").arg(label);
                }
                textFormat: Text.MarkdownText
            }
        }
    }
}
