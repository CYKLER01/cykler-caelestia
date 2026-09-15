pragma ComponentBehavior: Bound

import QtQuick
import qs.components.controls
import qs.modules.nexus.common

// SelectRow with the standard power-profile options (fork feature)
SelectRow {
    id: root

    property string value
    property bool showRestore: false
    property bool showUnchanged: false

    signal profileChanged(string newValue)

    // NOTE(fork): label is set by the caller via the `label` alias
    readonly property list<MenuItem> profileItems: {
        const items = [];

        if (root.showRestore)
            items.push(profileComp.createObject(root, { text: qsTr("Restore"), icon: "refresh", val: "restore" }));

        if (root.showUnchanged)
            items.push(profileComp.createObject(root, { text: qsTr("Unchanged"), icon: "block", val: "" }));

        items.push(profileComp.createObject(root, { text: qsTr("Power Saver"), icon: "battery_saver", val: "power-saver" }));
        items.push(profileComp.createObject(root, { text: qsTr("Balanced"), icon: "balance", val: "balanced" }));
        items.push(profileComp.createObject(root, { text: qsTr("Performance"), icon: "speed", val: "performance" }));

        return items;
    }

    menuItems: root.profileItems
    active: root.profileItems.find(item => item.val === root.value) ?? null

    onSelected: item => root.profileChanged(item.val)

    component ValMenuItem: MenuItem {
        property string val
    }

    readonly property Component profileComp: Component {
        ValMenuItem {}
    }
}
