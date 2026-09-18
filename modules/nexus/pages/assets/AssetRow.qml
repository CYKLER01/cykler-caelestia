import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.nexus.common

// NOTE(fork): a single editable caelestia asset, e.g. the logo or the session screen gif.
//
// Choosing a file copies it into the shell's data directory and points the option at that
// copy, the same way the profile picture is changed. The shell's own assets are never
// written to (they can be read only, e.g. under /etc/xdg), and the copy means the asset
// survives the original file being moved or deleted.
ConnectedRect {
    id: root

    required property string label
    required property string subtext
    // Name of the option, also used as the name of the copied file
    required property string option
    // The option's current value, and the value it falls back to
    required property string value
    required property string defaultValue
    // What the option currently resolves to, shown as the preview
    required property url previewSource
    // Applies the path of the copy to the option, and restores the option's default
    required property var write
    required property var reset

    // Animated assets are previewed with an animated image
    property bool previewAnimated
    property list<string> filters: Images.validImageExtensions

    readonly property bool customized: root.value !== root.defaultValue
    readonly property string sourceLabel: {
        if (root.value === root.defaultValue)
            return Tr.tr("Shell default");
        if (!root.value)
            return Tr.tr("None");
        return Paths.shortenHome(root.value);
    }
    // Covers both the missing (empty path) and unreadable cases. Only the image in use
    // is given a source, so there is only ever one status to look at.
    readonly property bool previewFailed: {
        const status = root.previewAnimated ? animatedPreview.status : staticPreview.status;
        return status === Image.Error || status === Image.Null;
    }

    // Copies the chosen file into the shell's data directory and points the option at it.
    // The copy keeps the option's name so repeat uploads reuse the same file.
    function choose(source: string): void {
        const dot = source.lastIndexOf(".");
        const ext = dot > source.lastIndexOf("/") ? source.slice(dot).toLowerCase() : "";
        const target = `${Paths.assetsdir}/${root.option}${ext}`;

        if (source === target)
            return;

        // A copy left by an earlier upload of this option, if any, is replaced by this one
        copyProcess.previous = root.value.startsWith(`${Paths.assetsdir}/`) ? root.value : "";
        copyProcess.source = source;
        copyProcess.copyTarget = target;
        copyProcess.command = ["sh", "-c", "mkdir -p \"$1\" && cp -- \"$2\" \"$3\"", "sh", Paths.assetsdir, source, target];
        copyProcess.running = true;
    }

    // Restores the option's default, dropping the copy if that's what it points at.
    function resetAsset(): void {
        if (root.value.startsWith(`${Paths.assetsdir}/`))
            CUtils.deleteFile(Qt.resolvedUrl(root.value));

        root.reset();
        Toaster.toast(Tr.tr("Asset reset"), Tr.tr("Using the shell's default image again"), "settings_backup_restore", Toast.Info);
    }

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + rowLayout.anchors.margins * 2

    Process {
        id: copyProcess

        property string source
        property string copyTarget
        // The copy this option had before, removed once the new one has landed
        property string previous

        // The data directory isn't guaranteed to exist, so it's created as part of the copy
        onExited: code => { // qmllint disable signal-handler-parameters
            if (code !== 0) {
                Toaster.toast(Tr.tr("Failed to set asset"), Paths.shortenHome(copyProcess.source), "error", Toast.Error);
                return;
            }

            if (copyProcess.previous)
                CUtils.deleteFile(Qt.resolvedUrl(copyProcess.previous));

            root.write(copyProcess.copyTarget);
            Toaster.toast(Tr.tr("Asset updated"), Paths.shortenHome(copyProcess.copyTarget), "image", Toast.Success);
        }
    }

    FileDialog {
        id: dialog

        title: Tr.tr("Choose an image")
        filterLabel: Tr.tr("Image files")
        filters: root.filters
        onAccepted: path => root.choose(path)
    }

    RowLayout {
        id: rowLayout

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        StyledClippingRect {
            implicitWidth: Tokens.padding.extraExtraLarge
            implicitHeight: Tokens.padding.extraExtraLarge
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerHigh

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: dialog.open()
            }

            Image {
                id: staticPreview

                anchors.fill: parent
                visible: !root.previewAnimated
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(Tokens.padding.extraExtraLarge * 2, Tokens.padding.extraExtraLarge * 2)
                source: root.previewAnimated ? "" : root.previewSource
            }

            AnimatedImage {
                id: animatedPreview

                anchors.fill: parent
                visible: root.previewAnimated
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                source: root.previewAnimated ? root.previewSource : ""
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: root.previewFailed
                text: "broken_image"
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.medium
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.label
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.subtext
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.sourceLabel
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        IconButton {
            icon: "folder_open"
            type: IconButton.Tonal
            onClicked: dialog.open()
        }

        IconButton {
            visible: root.customized
            icon: "restart_alt"
            type: IconButton.Tonal
            onClicked: root.resetAsset()
        }
    }
}
