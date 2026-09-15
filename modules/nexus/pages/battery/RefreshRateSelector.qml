pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import qs.components.controls
import qs.modules.nexus.common

// SelectRow with the monitor refresh-rate options (fork feature)
SelectRow {
    id: root

    property string value
    property bool showRestore: false
    property bool showUnchanged: false

    signal rateChanged(string newValue)

    // NOTE(fork): label is set by the caller via the `label` alias
    readonly property list<ValMenuItem> rateItems: {
        const items = [];

        if (root.showRestore)
            items.push(rateComp.createObject(root, { text: qsTr("Restore"), icon: "refresh", val: "restore" }));

        if (root.showUnchanged)
            items.push(rateComp.createObject(root, { text: qsTr("Unchanged"), icon: "block", val: "" }));

        const uniqueRates = new Set();

        for (const monitor of Hyprland.monitors.values) {
            const data = monitor.lastIpcObject;
            if (!data?.availableModes)
                continue;

            for (const mode of data.availableModes) {
                const match = mode.match(/@(\d+(?:\.\d+)?)Hz/);
                if (match)
                    uniqueRates.add(Math.round(parseFloat(match[1])));
            }
        }

        const sortedRates = [...uniqueRates].sort((a, b) => a - b);
        for (const rate of sortedRates)
            items.push(rateComp.createObject(root, { text: `${rate} Hz`, icon: "speed", val: rate.toString() }));

        items.push(rateComp.createObject(root, { text: qsTr("Auto (lowest)"), icon: "battery_saver", val: "auto" }));

        return items;
    }

    menuItems: root.rateItems
    active: root.rateItems.find(item => item.val === root.value) ?? null

    onSelected: item => root.rateChanged(item.val)

    component ValMenuItem: MenuItem {
        property string val
    }

    readonly property Component rateComp: Component {
        ValMenuItem {}
    }
}
