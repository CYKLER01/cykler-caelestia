pragma Singleton

import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.utils

Searcher {
    id: root

    property list<var> modeData: []
    property int modeRevision
    readonly property list<string> fallbackModes: ["Integrated", "Hybrid", "AsusMuxDgpu"]

    function transformSearch(search: string): string {
        return search.slice(`${GlobalConfig.launcher.actionPrefix}gpu `.length);
    }

    function reload(): void {
        getModes.running = false;
        root.modeData = root.fallbackModes.map(root.createMode);
        root.modeRevision++;
        getModes.running = true;
    }

    function createMode(mode: string): var {
        return {
            name: mode,
            desc: Tr.tr("Switch to %1 graphics mode").arg(mode),
            icon: "developer_board",
            onClicked: list => {
                list.screenState.launcher = false;
                Quickshell.execDetached(["supergfxctl", "--mode", mode]);
                Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", Tr.tr("GPU mode changed"), Tr.tr("Restart the computer for the new graphics mode to take effect.")]);
            }
        };
    }

    function canonicalMode(mode: string): string {
        const lower = mode.toLowerCase();
        const knownModes = {
            integrated: "Integrated",
            hybrid: "Hybrid",
            vfio: "Vfio",
            asusegpu: "AsusEgpu",
            asusmuxdgpu: "AsusMuxDgpu",
            compute: "Compute",
            dedicated: "Dedicated"
        };
        return knownModes[lower] ?? "";
    }

    function updateModes(output: string): void {
        const modes = [];
        const matches = output.match(/Integrated|Hybrid|VFIO|Vfio|AsusEgpu|AsusMuxDgpu|Compute|Dedicated/gi) ?? [];
        for (const match of matches) {
            const mode = root.canonicalMode(match);
            if (mode && !modes.includes(mode))
                modes.push(mode);
        }

        if (modes.length === 0)
            return;

        root.modeData = modes.map(root.createMode);
        root.modeRevision++;
    }

    list: root.modeData
    useFuzzy: false

    Component.onCompleted: root.reload()

    Connections {
        function onEnableSupergfxctlChanged(): void {
            root.reload();
        }

        target: Config.launcher
    }

    Process {
        id: getModes

        command: ["supergfxctl", "-s"]
        stdout: StdioCollector {
            onStreamFinished: root.updateModes(text)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn(`supergfxctl exited with code ${exitCode}`);
        }
    }
}
