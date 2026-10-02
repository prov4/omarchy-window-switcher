import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "WindowSearch.js" as WindowSearch

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property string filterText: ""
  property int selectedIndex: 0
  property var windows: []

  // Shares the [menu] surface tokens so themes that style the menu also
  // style the switcher.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md
  property int rowHeight: Math.max(Style.space(48), Style.font.body + Style.font.caption + Style.spacing.md * 2)
  property int iconSize: Math.round(rowHeight * 0.6)
  property int cardWidth: Math.min(Style.space(720), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(520), panel.height - Style.gapsOut * 2)

  function open(payloadJson) {
    root.filterText = ""
    root.selectedIndex = 0
    root.windows = []
    displayModel.clear()
    clientsProc.running = true
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "josip.window-switcher")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function loadClients(raw) {
    root.windows = WindowSearch.parseClients(raw)
    root.opened = true
    root.rebuildDisplay()
    // Alt-tab feel: preselect the previously focused window.
    if (displayModel.count > 1) root.selectedIndex = 1
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function iconFor(appClass) {
    if (!appClass) return ""
    var entry = DesktopEntries.heuristicLookup ? DesktopEntries.heuristicLookup(appClass) : null
    var name = entry && entry.icon ? entry.icon : appClass.toLowerCase()
    return Quickshell.iconPath(name, true)
  }

  function rebuildDisplay() {
    var out = WindowSearch.filterWindows(root.windows, root.filterText)
    displayModel.clear()
    for (var i = 0; i < out.length; i++) {
      var w = out[i]
      displayModel.append({
        address: w.address,
        app: w.app,
        title: w.title,
        workspace: w.workspace,
        icon: root.iconFor(w.appClass)
      })
    }
    root.selectedIndex = 0
    Qt.callLater(function() {
      if (displayModel.count > 0) resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    })
  }

  function select(delta) {
    if (displayModel.count === 0) return
    selectedIndex = (selectedIndex + delta + displayModel.count) % displayModel.count
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function selectPage(delta) {
    if (displayModel.count === 0) return
    var visibleRows = Math.max(1, Math.floor(resultList.height / rowHeight))
    selectedIndex = Math.max(0, Math.min(displayModel.count - 1, selectedIndex + delta * visibleRows))
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function setFilter(nextFilter) {
    root.filterText = nextFilter
    root.rebuildDisplay()
  }

  function activateIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var address = displayModel.get(index).address
    root.dismiss()
    Quickshell.execDetached(["bash", "-c",
      "hyprctl dispatch \"hl.dsp.focus({ window = \\\"address:$1\\\" })\" >/dev/null 2>&1 || hyprctl dispatch focuswindow \"address:$1\" >/dev/null",
      "_", address])
  }

  ListModel { id: displayModel }

  Process {
    id: clientsProc
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      onStreamFinished: root.loadClients(text)
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "josip-window-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          var ctrl = event.modifiers & Qt.ControlModifier
          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.dismiss()
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
          } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab
                     || (ctrl && (event.key === Qt.Key_P || event.key === Qt.Key_K))) {
            root.select(-1)
          } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab
                     || (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_J))) {
            root.select(1)
          } else if (event.key === Qt.Key_PageUp) {
            root.selectPage(-1)
          } else if (event.key === Qt.Key_PageDown) {
            root.selectPage(1)
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activateIndex(root.selectedIndex)
          } else if (!ctrl && event.text && event.text.length === 1
                     && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
          } else {
            return
          }
          event.accepted = true
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Item {
          width: parent.width
          height: root.headerHeight

          Text {
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.right: countLabel.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.filterText || "Search windows…"
            color: root.foreground
            opacity: root.filterText ? 1 : 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
          }

          Text {
            id: countLabel
            textFormat: Text.PlainText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: displayModel.count + "/" + root.windows.length
            color: root.foreground
            opacity: 0.5
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Item {
          width: parent.width
          height: parent.height - root.headerHeight - root.contentSpacing

          ListView {
            id: resultList
            anchors.fill: parent
            model: displayModel
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
              required property int index
              required property string app
              required property string title
              required property string workspace
              required property string icon

              readonly property bool hasCursor: index === root.selectedIndex

              width: resultList.width
              height: root.rowHeight
              radius: root.cornerRadius
              color: hasCursor ? root.selectedBackground : "transparent"

              IconImage {
                id: appIcon
                anchors.left: parent.left
                anchors.leftMargin: Style.spacing.md
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: root.iconSize
                source: parent.icon
                visible: !!parent.icon
              }

              Column {
                anchors.left: appIcon.right
                anchors.leftMargin: Style.spacing.md
                anchors.right: wsLabel.left
                anchors.rightMargin: Style.spacing.md
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: title
                  color: hasCursor ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: app
                  color: hasCursor ? root.selectedText : root.foreground
                  opacity: 0.6
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              Text {
                id: wsLabel
                anchors.right: parent.right
                anchors.rightMargin: Style.spacing.md
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: workspace
                color: hasCursor ? root.selectedText : root.foreground
                opacity: 0.5
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: root.selectedIndex = index
                onClicked: root.activateIndex(index)
              }
            }
          }

          Text {
            anchors.centerIn: parent
            visible: displayModel.count === 0 && root.opened
            textFormat: Text.PlainText
            text: root.filterText ? "No windows match “" + root.filterText + "”" : "No open windows"
            color: root.foreground
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
          }
        }
      }
    }
  }
}
