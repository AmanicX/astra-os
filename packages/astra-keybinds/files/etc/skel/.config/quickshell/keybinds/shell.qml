import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    // ------------------------------------------------------------ palette
    // Deliberately neutral: no terminal or desktop theme colors.
    readonly property string fg: "#f4f4f5"
    readonly property string muted: "#8b8b90"
    readonly property string faint: "#616166"
    readonly property string hairline: "#14ffffff"
    readonly property string fill: "#08ffffff"
    readonly property string fillStrong: "#12ffffff"
    readonly property string errorColor: "#ff9b9b"

    // ------------------------------------------------------------ state
    property bool opened: false
    property bool shown: false
    property bool mapped: false
    property string query: ""
    property string activeGroup: "All"
    property int selected: 0


    // ------------------------------------------------------------ data
    FileView {
        id: bindsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/keybinds/keybinds.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    // Rebuild the overlay data whenever the standalone keybind file changes.
    FileView {
        id: keybindsSource
        path: Quickshell.env("HOME") + "/.config/niri/keybinds.kdl"
        watchChanges: true
        onFileChanged: {
            reload();
            regenerate.running = true;
        }
    }

    Process {
        id: regenerate
        command: [
            "python3",
            "/usr/share/astra/keybinds/gen-keybinds.py"
        ]
        onExited: bindsFile.reload()
    }

    property var data: {
        try {
            return JSON.parse(bindsFile.text());
        } catch (e) {
            return {
                groups: []
            };
        }
    }

    property var groupNames: {
        var names = ["All"];
        var gs = (data && data.groups) ? data.groups : [];
        for (var i = 0; i < gs.length; i++)
            names.push(gs[i].name);
        return names;
    }

    // ------------------------------------------------------------ layout
    function buildLayout() {
        var groups = (data && data.groups) ? data.groups : [];
        var items = [];
        var flat = [];
        var q = query.trim().toLowerCase();

        for (var g = 0; g < groups.length; g++) {
            var grp = groups[g];
            if (activeGroup !== "All" && grp.name !== activeGroup)
                continue;

            var matched = [];
            for (var i = 0; i < grp.items.length; i++) {
                var it = grp.items[i];
                var hay = ((it.search || "") + " " + it.keys + " " + it.title).toLowerCase();
                if (q !== "" && hay.indexOf(q) === -1)
                    continue;
                matched.push(it);
            }
            if (matched.length === 0)
                continue;

            items.push({
                header: true,
                name: grp.name,
                cont: false
            });
            for (var j = 0; j < matched.length; j++) {
                var b = matched[j];
                flat.push(b);
                items.push({
                    header: false,
                    idx: flat.length - 1,
                    group: grp.name,
                    keys: b.keys,
                    title: b.title,
                    action: b.action
                });
            }
        }

        var avail = columnsArea.height > 60 ? columnsArea.height : 740;
        var rowH = 23;
        var maxRows = Math.max(12, Math.floor(avail / rowH));
        var totalWeight = 0;
        for (var k = 0; k < items.length; k++)
            totalWeight += items[k].header ? 1.39 : 1;

        var minimum = (q === "" && activeGroup === "All") ? 3 : 1;
        var count = Math.max(minimum, Math.min(6, Math.ceil(totalWeight / maxRows)));
        var columns = [];
        for (var c = 0; c < count; c++)
            columns.push([]);
        if (items.length > 0) {
            var target = totalWeight / count;
            var acc = 0;
            var col = 0;
            for (var m = 0; m < items.length; m++) {
                var w = items[m].header ? 1.39 : 1;
                while (col < count - 1 && acc + w / 2 > target * (col + 1))
                    col++;
                columns[col].push(items[m]);
                acc += w;
            }
        }

        // A section header may not be the last row in a column.
        for (var c2 = 0; c2 < columns.length; c2++) {
            while (columns[c2].length > 0 && columns[c2][columns[c2].length - 1].header)
                columns[c2].pop();
        }
        // Repeat the section name when a section continues in a new column.
        for (var c3 = 0; c3 < columns.length; c3++) {
            if (columns[c3].length > 0 && !columns[c3][0].header) {
                columns[c3].unshift({
                    header: true,
                    name: columns[c3][0].group,
                    cont: true
                });
            }
        }

        return {
            columns: columns,
            flat: flat,
            total: flat.length
        };
    }

    property var layout: buildLayout()
    onLayoutChanged: {
        if (selected >= layout.flat.length)
            selected = Math.max(0, layout.flat.length - 1);
    }

    // ------------------------------------------------------------ actions
    function reset() {
        query = "";
        activeGroup = "All";
        selected = 0;
        searchInput.text = "";
    }

    function show() {
        reset();
        mapped = true;
        opened = true;
        Qt.callLater(function() {
            shown = true;
            searchInput.forceActiveFocus();
        });
    }

    function hide() {
        shown = false;
        hideTimer.restart();
    }

    function toggle() {
        if (opened)
            hide();
        else
            show();
    }

    function select(delta) {
        if (layout.flat.length === 0)
            return;
        selected = (selected + delta + layout.flat.length) % layout.flat.length;
    }

    function runSelected() {
        var item = layout.flat[selected];
        if (!item)
            return;
        var cmd = item.exec || [];
        hide();
        if (cmd.length > 0) {
            Qt.callLater(function() {
                Quickshell.execDetached(cmd);
            });
        }
    }


    Timer {
        id: hideTimer
        interval: 150
        onTriggered: {
            root.mapped = false;
            root.opened = false;
        }
    }


    IpcHandler {
        target: "keybinds"
        function toggle(): void {
            root.toggle();
        }
        function open(): void {
            root.show();
        }
        function close(): void {
            root.hide();
        }
    }

    // ------------------------------------------------------------ window
    PanelWindow {
        id: win
        visible: root.mapped
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        color: "transparent"
        focusable: root.opened
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "keybinds"
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: "#99000000"
            opacity: root.shown ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(parent.width - 64, 1760)
            height: Math.min(parent.height - 64, 1000)
            radius: 16
            color: "#f20b0b0c"
            border.width: 1
            border.color: root.hairline
            opacity: root.shown ? 1 : 0
            scale: root.shown ? 1 : 0.98
            Behavior on opacity {
                NumberAnimation {
                    duration: 170
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
            }

            Item {
                id: content
                anchors.fill: parent
                anchors.margins: 28

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // ------------------------------------------------ header
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Keybindings"
                            color: root.fg
                            font.family: "Adwaita Sans"
                            font.pixelSize: 22
                            font.bold: true
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: layout.total + (layout.total === 1 ? " shortcut" : " shortcuts")
                            color: root.faint
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                    }

                    // ------------------------------------------------ search
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 9
                        color: root.fill
                        border.width: 1
                        border.color: searchInput.activeFocus ? "#4dffffff" : root.hairline

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        TextInput {
                            id: searchInput
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.right: clearHint.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            height: 22
                            color: root.fg
                            selectionColor: "#33ffffff"
                            selectedTextColor: root.fg
                            font.family: "Adwaita Sans"
                            font.pixelSize: 14
                            clip: true
                            onTextChanged: {
                                root.query = text;
                                root.selected = 0;
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: searchInput.text === ""
                                text: "Search shortcuts"
                                color: root.muted
                                font.family: "Adwaita Sans"
                                font.pixelSize: 14
                            }

                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Down) {
                                    root.select(1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    root.select(-1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_PageDown) {
                                    root.select(8);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_PageUp) {
                                    root.select(-8);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.runSelected();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    root.hide();
                                    event.accepted = true;
                                }
                            }
                        }

                        Text {
                            id: clearHint
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "esc"
                            visible: searchInput.text !== ""
                            color: root.faint
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12
                    }

                    // ------------------------------------------------ filters
                    Row {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        spacing: 0

                        Repeater {
                            model: groupNames

                            Item {
                                property bool active: root.activeGroup === modelData
                                width: filterLabel.implicitWidth + 22
                                height: 28

                                Text {
                                    id: filterLabel
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: parent.active ? root.fg : root.muted
                                    font.family: "Adwaita Sans"
                                    font.pixelSize: 12
                                }

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    width: filterLabel.implicitWidth
                                    height: 1
                                    color: root.fg
                                    visible: parent.active
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.activeGroup = modelData;
                                        root.selected = 0;
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.hairline
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 10
                    }

                    // ------------------------------------------------ columns
                    Item {
                        id: columnsArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        Row {
                            id: columnsRow
                            anchors.fill: parent
                            spacing: 26

                            Repeater {
                                model: layout.columns

                                Flickable {
                                    id: flick
                                    width: (columnsRow.width - (layout.columns.length - 1) * columnsRow.spacing) / Math.max(1, layout.columns.length)
                                    height: columnsRow.height
                                    contentWidth: width
                                    contentHeight: columnBody.implicitHeight
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds

                                    Column {
                                        id: columnBody
                                        width: parent.width
                                        spacing: 0

                                        Repeater {
                                            model: modelData

                                            Item {
                                                width: columnBody.width
                                                height: modelData.header ? 32 : 23

                                                Item {
                                                    visible: modelData.header
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.top: parent.top
                                                    height: 32

                                                    Text {
                                                        anchors.left: parent.left
                                                        anchors.bottom: parent.bottom
                                                        anchors.bottomMargin: 7
                                                        text: modelData.header ? modelData.name.toUpperCase() : ""
                                                        color: root.muted
                                                        font.family: "Adwaita Sans"
                                                        font.pixelSize: 10
                                                        font.bold: true
                                                        font.letterSpacing: 1.4
                                                        opacity: modelData.cont ? 0.65 : 1
                                                    }

                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.right: parent.right
                                                        anchors.bottom: parent.bottom
                                                        height: 1
                                                        color: root.hairline
                                                    }
                                                }

                                                Rectangle {
                                                    visible: !modelData.header
                                                    anchors.fill: parent
                                                    radius: 5
                                                    property bool hovered: rowMouse.containsMouse
                                                    property bool isSelected: !modelData.header && root.selected === modelData.idx
                                                    color: isSelected ? root.fillStrong : "transparent"

                                                    Rectangle {
                                                        visible: root.selected === modelData.idx
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        width: 2
                                                        radius: 1
                                                        color: root.fg
                                                    }

                                                    Text {
                                                        id: keyText
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 8
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: Math.min(implicitWidth, parent.width * 0.68)
                                                        text: modelData.header ? "" : modelData.keys
                                                        color: root.fg
                                                        opacity: root.selected === modelData.idx ? 1 : 0.78
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 11
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        anchors.left: keyText.right
                                                        anchors.leftMargin: 12
                                                        anchors.right: parent.right
                                                        anchors.rightMargin: 8
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: modelData.header ? "" : modelData.title
                                                        color: root.muted
                                                        opacity: root.selected === modelData.idx ? 1 : 0.9
                                                        font.family: "Adwaita Sans"
                                                        font.pixelSize: 12
                                                        elide: Text.ElideRight
                                                    }


                                                    MouseArea {
                                                        id: rowMouse
                                                        anchors.fill: parent
                                                        onClicked: root.selected = modelData.idx
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    WheelHandler {
                                        onWheel: function(event) {
                                            var maxY = Math.max(0, flick.contentHeight - flick.height);
                                            flick.contentY = Math.max(0, Math.min(maxY, flick.contentY - event.angleDelta.y / 2));
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            visible: layout.total === 0

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "No shortcuts found"
                                color: root.fg
                                font.family: "Adwaita Sans"
                                font.pixelSize: 13
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Try another search or category."
                                color: root.muted
                                font.family: "Adwaita Sans"
                                font.pixelSize: 12
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12
                    }

                    // ------------------------------------------------ footer
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, parent.width * 0.55)
                            text: layout.flat.length > 0 ? layout.flat[Math.min(root.selected, layout.flat.length - 1)].action : ""
                            color: root.faint
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 16

                            Text {
                                text: "Up/Down navigate"
                                color: root.faint
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                            }
                            Text {
                                text: "Enter run"
                                color: root.faint
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                            }
                            Text {
                                text: "Esc close"
                                color: root.faint
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }

        }
    }
}
