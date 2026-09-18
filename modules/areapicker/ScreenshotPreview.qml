pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

// NOTE(fork): the preview shown once a screenshot has been captured.
//
// The capture is already on the clipboard by the time this appears, so the preview
// only exists to offer a short window in which the capture can be handed to an
// editor. If that window passes without a click, the temporary file is cleared and
// the clipboard keeps the image.
StyledWindow {
    id: root

    // How long to wait for a click before discarding the capture.
    readonly property int timeout: 3000
    // The bar owns the left edge, so the preview sits to the right of it.
    readonly property int barWidth: ShellState.componentsFor(root.screen)?.bar?.implicitWidth ?? 0
    // Local path of the capture being previewed, empty while the preview is idle.
    property string capturePath

    function capture(path: string, target: ShellScreen): void {
        // Clear any capture still being previewed before taking over.
        root.dismiss();

        root.screen = target;
        root.capturePath = path;
        root.visible = true;
        timer.restart();
    }

    // Put the preview away and clear the capture's temporary file.
    function dismiss(): void {
        timer.stop();
        root.visible = false;

        if (root.capturePath)
            CUtils.deleteFile(Qt.resolvedUrl(root.capturePath));

        root.capturePath = "";
    }

    // Hand the capture to the editor, which keeps the file to save its edits into.
    function edit(): void {
        const path = root.capturePath;
        if (!path)
            return;

        timer.stop();
        root.visible = false;
        root.capturePath = "";
        Quickshell.execDetached(["swappy", "-f", path]);
    }

    name: "screenshot-preview"

    visible: false
    // While idle the window must not swallow clicks in the corner it sits in.
    mask: root.visible ? null : empty
    margins.bottom: card.edgeMargin
    margins.left: root.barWidth + card.edgeMargin
    anchors.bottom: true
    anchors.left: true
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // Never take keyboard focus away from whatever the user was doing.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    Region {
        id: empty
    }

    Timer {
        id: timer

        interval: root.timeout
        onTriggered: root.dismiss()
    }

    StyledClippingRect {
        id: card

        // Gap kept from the bar and the screen edges.
        readonly property int edgeMargin: Tokens.padding.large
        // Captures are usually screen sized, so keep the preview a thumbnail.
        readonly property real maxWidth: Math.round((root.screen?.width ?? 0) / 4)
        readonly property real maxHeight: Math.round((root.screen?.height ?? 0) / 4)

        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.large
        implicitWidth: img.width + Tokens.padding.small * 2
        implicitHeight: img.height + Tokens.padding.small * 2
        anchors.fill: parent

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.edit()
        }

        Image {
            id: img

            // The image is sized to the capture's own aspect ratio and never blown up
            // past the bounds of the thumbnail, so a small capture previews small.
            readonly property real previewScale: implicitWidth > 0 && implicitHeight > 0 ? Math.min(1, card.maxWidth / implicitWidth, card.maxHeight / implicitHeight) : 1

            // Bound the decoded size so a full screen capture isn't decoded at full
            // resolution only to be shown as a thumbnail.
            sourceSize: Qt.size(card.maxWidth * 2, card.maxHeight * 2)
            width: Math.round(implicitWidth * previewScale)
            height: Math.round(implicitHeight * previewScale)
            anchors.centerIn: parent
            asynchronous: true
            fillMode: Image.PreserveAspectFit
            source: root.capturePath ? Qt.resolvedUrl(root.capturePath) : ""
        }
    }
}
