import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Facelock-shaped tile: a card drops under the bar, scans, then checks or shakes.
// Enter libera a RTX e sobe VFIO; S inicia o mesmo Windows com vídeo SPICE.
Item {
  id: root

  property var shell: null
  property var manifest: null
  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "psycrow.winmarchy"
  readonly property string pluginDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property string gateBin: pluginDir + "/bin/gate"
  readonly property string homeDir: Quickshell.env("HOME") || ""
  readonly property string configPath: homeDir + "/.config/omarchy/winmarchy-vfio.json"
  property string locale: {
    var lang = String(Quickshell.env("LANG") || "").toLowerCase()
    if (lang.indexOf("pt") === 0) return "pt-BR"
    return "en-US"
  }
  property var strings: ({})

  function normalizeLocale(value) {
    var raw = String(value || "").trim().replace("_", "-")
    var lower = raw.toLowerCase()
    if (lower.indexOf("pt") === 0) return "pt-BR"
    if (lower.indexOf("en") === 0) return "en-US"
    if (raw === "pt-BR" || raw === "en-US") return raw
    return ""
  }

  function detectLocale() {
    var forced = normalizeLocale(Quickshell.env("WIN11_VFIO_LOCALE"))
    if (forced) return forced
    if (configFile.text()) {
      var data = parseJson(configFile.text())
      forced = normalizeLocale(data.locale)
      if (forced) return forced
    }
    forced = normalizeLocale(Quickshell.env("LANG"))
    return forced || "en-US"
  }

  function loadStrings() {
    locale = detectLocale()
    var parsed = parseJson(stringsFile.text())
    if (parsed && typeof parsed === "object" && !parsed.error) strings = parsed
  }

  function tr(key) {
    if (strings && strings[key]) return strings[key]
    return key
  }

  property bool opened: false
  property string phase: "scan"   // scan | confirm | go | ok | fail | blocked
  property string errorText: ""
  property var groups: []
  property bool fatal: false
  property string goMode: "vfio"
  property color green: "#34c759"

  readonly property bool scanning: phase === "scan" || phase === "go"
  readonly property color tone: phase === "ok" ? green : (phase === "fail" || phase === "blocked") ? Color.urgent : Color.accent
  readonly property string uiFont: Style.font.family
  readonly property int hudWidth: Style.space(268)
  readonly property int glyphSize: Style.space(78)
  readonly property string glyphIcon: "\u{F05B3}"

  readonly property string title: phase === "ok" ? (goMode === "shared" ? tr("title_ok_shared") : tr("title_ok_vfio"))
    : phase === "fail" ? tr("title_fail")
    : phase === "blocked" ? tr("title_blocked")
    : phase === "go" ? (goMode === "shared" ? tr("title_go_shared") : tr("title_go_vfio"))
    : phase === "confirm" && fatal ? tr("title_confirm_fatal")
    : phase === "confirm" ? tr("title_confirm")
    : tr("title_scan")

  readonly property string subtitle: phase === "ok" ? (goMode === "shared" ? tr("sub_ok_shared") : tr("sub_ok_vfio"))
    : phase === "fail" ? (errorText || tr("sub_fail_fallback"))
    : phase === "blocked" ? tr("sub_blocked")
    : phase === "go" ? (goMode === "shared" ? tr("sub_go_shared") : tr("sub_go_vfio"))
    : phase === "confirm" && fatal ? tr("sub_confirm_fatal")
    : phase === "confirm" ? (groups && groups.length ? processLine : tr("sub_confirm_free"))
    : tr("sub_scan")

  readonly property string processLine: {
    if (!groups || groups.length === 0) return tr("process_none")
    var names = []
    for (var i = 0; i < groups.length; i++) names.push(groups[i].label)
    return names.join(" · ")
  }

  function open(payloadJson) {
    errorText = ""
    groups = []
    fatal = false
    goMode = "vfio"
    phase = "scan"
    opened = true
    successAnim.stop(); failAnim.stop()
    frame.morph = 0; frame.check = 0; hud.shakeX = 0; hud.pop = 1; ripple.progress = 0
    var payload = parseJson(payloadJson)
    if (payload && payload.mode === "shared") {
      goNow("shared")
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      return
    }
    Qt.callLater(function() { keyCatcher.forceActiveFocus(); kick(holdersProc) })
  }

  function close() { opened = false }

  function dismiss() {
    opened = false
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
  }

  function toggle() { opened ? dismiss() : open("{}") }

  function parseJson(raw) {
    try { return JSON.parse(raw || "{}") } catch (e) { return { ok: false, error: String(e) } }
  }

  function kick(proc) {
    if (proc.running) proc.running = false
    proc.running = true
  }

  function applyHolders(raw) {
    var data = parseJson(raw)
    if (!data.ok) { failWith(data.error || tr("err_gpu_read")); return }
    groups = data.groups || []
    fatal = !!data.fatal
    phase = "confirm"
    if (fatal) failAnim.restart()
  }

  function goNow(mode) {
    if (phase === "go" || phase === "ok") return
    var chosen = mode || "vfio"
    if (chosen === "vfio" && fatal) return
    goMode = chosen
    phase = "go"
    goProc.command = ["/usr/bin/python3", root.gateBin, "go", chosen]
    kick(goProc)
  }

  function applyGo(raw) {
    var data = parseJson(raw)
    if (!data.ok) {
      failWith(data.error || tr("err_vm_start"))
      return
    }
    if (data.mode) goMode = data.mode
    phase = "ok"
    successAnim.restart()
    if (goMode === "shared") {
      Quickshell.execDetached(["/usr/bin/virt-viewer", "-c", "qemu:///system", "--attach", "--wait", "win11-shared"])
    } else {
      Quickshell.execDetached(["/usr/bin/env", "LIBVA_DRIVER_NAME=iHD", "__GLX_VENDOR_LIBRARY_NAME=mesa", "__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json", "looking-glass-client"])
    }
    hideTimer.interval = 1600
    hideTimer.restart()
  }

  function failWith(msg) {
    errorText = String(msg || "")
    phase = "fail"
    failAnim.restart()
    hideTimer.interval = 2800
    hideTimer.restart()
  }

  Timer {
    id: hideTimer
    onTriggered: root.dismiss()
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      root.locale = root.detectLocale()
      stringsFile.reload()
    }
  }

  FileView {
    id: stringsFile
    path: root.pluginDir + "/i18n/" + root.locale + ".json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.loadStrings()
  }

  FileView {
    path: Color.currentThemePath + "/colors.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var m = String(text()).match(/^\s*(?:green|color2)\s*=\s*["']?(#[0-9A-Fa-f]{6})/m)
      if (m) root.green = m[1]
    }
  }

  SequentialAnimation {
    running: root.opened && root.scanning
    loops: Animation.Infinite
    NumberAnimation { target: glyph; property: "beam"; from: 0; to: 1; duration: 900; easing.type: Easing.InOutSine }
    NumberAnimation { target: glyph; property: "beam"; from: 1; to: 0; duration: 900; easing.type: Easing.InOutSine }
  }
  SequentialAnimation {
    running: root.opened && root.scanning
    loops: Animation.Infinite
    NumberAnimation { target: glyph; property: "breathe"; from: 0; to: 1; duration: 650; easing.type: Easing.InOutSine }
    NumberAnimation { target: glyph; property: "breathe"; from: 1; to: 0; duration: 650; easing.type: Easing.InOutSine }
  }
  SequentialAnimation {
    id: successAnim
    NumberAnimation { target: glyph; property: "breathe"; to: 0; duration: 80 }
    ParallelAnimation {
      NumberAnimation { target: frame; property: "morph"; from: 0; to: 1; duration: 340; easing.type: Easing.OutCubic }
      NumberAnimation { target: ripple; property: "progress"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
      SequentialAnimation {
        NumberAnimation { target: hud; property: "pop"; to: 1.05; duration: 150; easing.type: Easing.OutQuad }
        NumberAnimation { target: hud; property: "pop"; to: 1; duration: 320; easing.type: Easing.OutBack }
      }
      SequentialAnimation {
        PauseAnimation { duration: 220 }
        NumberAnimation { target: frame; property: "check"; from: 0; to: 1; duration: 280; easing.type: Easing.OutCubic }
      }
    }
  }
  SequentialAnimation {
    id: failAnim
    NumberAnimation { target: hud; property: "shakeX"; to: -14; duration: 55; easing.type: Easing.OutQuad }
    NumberAnimation { target: hud; property: "shakeX"; to: 12; duration: 70; easing.type: Easing.InOutQuad }
    NumberAnimation { target: hud; property: "shakeX"; to: -9; duration: 65; easing.type: Easing.InOutQuad }
    NumberAnimation { target: hud; property: "shakeX"; to: 6; duration: 60; easing.type: Easing.InOutQuad }
    NumberAnimation { target: hud; property: "shakeX"; to: -3; duration: 55; easing.type: Easing.InOutQuad }
    NumberAnimation { target: hud; property: "shakeX"; to: 0; duration: 50; easing.type: Easing.OutQuad }
  }

  Process {
    id: holdersProc
    command: ["/usr/bin/python3", root.gateBin, "holders"]
    stdout: StdioCollector { id: holdersOut; waitForEnd: true }
    stderr: StdioCollector { id: holdersErr; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0 && !holdersOut.text) root.failWith(holdersErr.text || root.tr("err_holders"))
      else root.applyHolders(holdersOut.text)
    }
  }

  Process {
    id: goProc
    command: ["/usr/bin/python3", root.gateBin, "go", root.goMode]
    stdout: StdioCollector { id: goOut; waitForEnd: true }
    stderr: StdioCollector { id: goErr; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0 && !goOut.text) root.failWith(goErr.text || root.tr("err_gate"))
      else root.applyGo(goOut.text)
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened || hud.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "winmarchy-vfio"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
      anchors.fill: parent
      enabled: root.opened && root.phase === "confirm"
      onClicked: root.dismiss()
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          if (root.phase === "confirm" || root.phase === "fail" || root.phase === "blocked") root.dismiss()
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          if (root.phase === "confirm") root.goNow("vfio")
          event.accepted = true
        } else if (event.key === Qt.Key_S) {
          if (root.phase === "confirm") root.goNow("shared")
          event.accepted = true
        }
      }
    }

    Item {
      id: hud
      property real pop: 1
      property real shakeX: 0
      width: root.hudWidth
      height: content.implicitHeight + Style.space(24) + Style.space(20)
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: Style.space(64)
      opacity: root.opened ? 1 : 0
      scale: root.opened ? 1 : 0.9
      Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
      transform: [
        Scale { origin.x: hud.width / 2; origin.y: hud.height / 2; xScale: hud.pop; yScale: hud.pop },
        Translate { x: hud.shakeX }
      ]

      MouseArea { anchors.fill: parent; onClicked: function(mouse) { mouse.accepted = true } }

      BorderSurface {
        id: card
        anchors.fill: parent
        radius: Style.cornerRadius
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
        gradient: Gradient {
          GradientStop { position: 0; color: Util.alpha(Qt.lighter(Color.popups.background, 1.3), 0.97) }
          GradientStop { position: 1; color: Util.alpha(Color.popups.background, 0.97) }
        }
        layer.enabled: true
        layer.effect: MultiEffect {
          shadowEnabled: true
          shadowColor: "#000000"
          shadowOpacity: 0.6
          shadowBlur: 1.0
          blurMax: 48
          shadowVerticalOffset: Style.space(10)
        }
      }

      Rectangle {
        anchors {
          left: parent.left; right: parent.right; top: parent.top
          leftMargin: card.borderLeft; rightMargin: card.borderRight; topMargin: card.borderTop
        }
        height: parent.height * 0.5
        radius: Math.max(0, Style.cornerRadius - card.borderTop)
        gradient: Gradient {
          GradientStop { position: 0; color: Util.alpha(Color.foreground, 0.06) }
          GradientStop { position: 1; color: Util.alpha(Color.foreground, 0) }
        }
      }

      Column {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Style.space(24)
        spacing: 0

        Item {
          id: stage
          width: root.glyphSize * 1.5
          height: root.glyphSize * 1.3
          anchors.horizontalCenter: parent.horizontalCenter

          Rectangle {
            id: ripple
            property real progress: 0
            anchors.centerIn: parent
            width: root.glyphSize * (0.86 + 0.5 * progress)
            height: width
            radius: Style.cornerRadius
            color: "transparent"
            border.width: Math.max(1, Style.space(2))
            border.color: root.green
            opacity: progress > 0 && progress < 1 ? 0.6 * (1 - progress) : 0
          }

          Item {
            id: face
            anchors.centerIn: parent
            width: root.glyphSize
            height: root.glyphSize
            opacity: 1 - frame.morph
            scale: (1 - 0.06 * glyph.breathe) * (1 - 0.2 * frame.morph)
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: root.glyphIcon
              font.family: Style.font.family
              font.pixelSize: root.glyphSize
              color: root.tone
              Behavior on color { ColorAnimation { duration: 220 } }
            }
            Item {
              anchors.centerIn: parent
              width: root.glyphSize * 0.86
              height: width
              clip: true
              visible: root.scanning
              Rectangle {
                width: parent.width
                height: parent.height * 0.34
                y: glyph.beam * parent.height - height / 2
                gradient: Gradient {
                  GradientStop { position: 0; color: Util.alpha(Color.accent, 0) }
                  GradientStop { position: 0.5; color: Util.alpha(Color.accent, 0.26) }
                  GradientStop { position: 1; color: Util.alpha(Color.accent, 0) }
                }
              }
              Rectangle {
                width: parent.width
                height: Math.max(1, Style.space(2))
                y: glyph.beam * parent.height - height / 2
                color: Color.accent
                opacity: 0.9
              }
            }
          }

          QtObject {
            id: glyph
            property real beam: 0
            property real breathe: 0
          }

          Canvas {
            id: frame
            anchors.centerIn: parent
            width: root.glyphSize
            height: root.glyphSize
            visible: morph > 0.001
            property real morph: 0
            property real check: 0
            property color tone: root.green
            onMorphChanged: requestPaint()
            onCheckChanged: requestPaint()
            onToneChanged: requestPaint()
            onWidthChanged: requestPaint()
            function paintCheck(ctx, s, lw) {
              if (check <= 0.001) return
              var p0 = [0.3, 0.52], p1 = [0.44, 0.66], p2 = [0.7, 0.36]
              var l1 = Math.hypot(p1[0] - p0[0], p1[1] - p0[1])
              var l2 = Math.hypot(p2[0] - p1[0], p2[1] - p1[1])
              var d = check * (l1 + l2)
              ctx.lineWidth = Math.round(lw * 1.2)
              ctx.beginPath()
              ctx.moveTo(p0[0] * s, p0[1] * s)
              if (d <= l1) {
                var t = d / l1
                ctx.lineTo((p0[0] + (p1[0] - p0[0]) * t) * s, (p0[1] + (p1[1] - p0[1]) * t) * s)
              } else {
                var t2 = (d - l1) / l2
                ctx.lineTo(p1[0] * s, p1[1] * s)
                ctx.lineTo((p1[0] + (p2[0] - p1[0]) * t2) * s, (p1[1] + (p2[1] - p1[1]) * t2) * s)
              }
              ctx.stroke()
            }
            function rgba(c, a) {
              return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")"
            }
            onPaint: {
              var ctx = getContext("2d")
              ctx.reset()
              ctx.clearRect(0, 0, width, height)
              var s = width
              var lw = Math.max(2, Math.round(s * 0.055))
              var a = s * 0.07 + lw / 2
              var side = s - 2 * a
              ctx.lineCap = "square"
              ctx.lineJoin = "miter"
              ctx.lineWidth = lw
              ctx.strokeStyle = rgba(tone, 1)
              ctx.fillStyle = rgba(tone, 0.14 * morph)
              ctx.fillRect(a, a, side, side)
              var left = 4 * side * morph
              var pts = [[a + side, a], [a + side, a + side], [a, a + side], [a, a]]
              var x = a, y = a
              ctx.beginPath()
              ctx.moveTo(x, y)
              for (var i = 0; i < 4 && left > 0; i++) {
                var step = Math.min(side, left)
                ctx.lineTo(x + (pts[i][0] - x) * step / side, y + (pts[i][1] - y) * step / side)
                x = pts[i][0]; y = pts[i][1]
                left -= step
              }
              ctx.stroke()
              paintCheck(ctx, s, lw)
            }
          }
        }

        Item { width: 1; height: Style.space(8) }

        Text {
          id: titleText
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: root.title
          width: root.hudWidth - Style.space(28)
          horizontalAlignment: Text.AlignHCenter
          fontSizeMode: Text.HorizontalFit
          minimumPixelSize: Math.round(Style.font.bodySmall)
          font.family: root.uiFont
          font.pixelSize: Math.round(Style.font.title * 1.15)
          font.bold: true
          color: Color.popups.text
        }

        Item { width: 1; height: Style.space(4) }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: root.subtitle
          width: root.hudWidth - Style.space(24)
          wrapMode: Text.Wrap
          horizontalAlignment: Text.AlignHCenter
          font.family: root.uiFont
          font.pixelSize: Style.font.bodySmall
          color: Util.alpha(Color.popups.text, 0.6)
        }

        Item { width: 1; height: Style.space(12) }

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: badgeRow.implicitWidth + Style.space(16)
          height: badgeRow.implicitHeight + Style.space(6)
          radius: Style.cornerRadius
          color: Util.alpha(Color.popups.text, 0.06)
          border.width: 1
          border.color: Util.alpha(Color.popups.text, 0.16)
          Row {
            id: badgeRow
            anchors.centerIn: parent
            spacing: Style.space(6)
            Text {
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: "\u{F0483}"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Color.accent
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: root.goMode === "shared" ? "WIN11 SPICE" : "WIN11 VFIO"
              font.family: root.uiFont
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.5
              color: Util.alpha(Color.popups.text, 0.78)
            }
          }
        }

        Item { width: 1; height: Style.space(10); visible: root.phase === "confirm" }

        Column {
          visible: root.phase === "confirm"
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(6)

          Rectangle {
            visible: !root.fatal
            width: Math.max(vfioLabel.implicitWidth + Style.space(20), spiceLabel.implicitWidth + Style.space(20))
            height: vfioLabel.implicitHeight + Style.space(10)
            radius: Style.cornerRadius
            color: Util.alpha(Color.accent, 0.16)
            border.width: 1
            border.color: Util.alpha(Color.accent, 0.55)
            Text {
              id: vfioLabel
              anchors.centerIn: parent
              text: root.groups && root.groups.length ? root.tr("btn_vfio_busy") : root.tr("btn_vfio_free")
              font.family: root.uiFont
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              color: Color.popups.text
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.goNow("vfio")
            }
          }

          Rectangle {
            width: Math.max(vfioLabel.implicitWidth + Style.space(20), spiceLabel.implicitWidth + Style.space(20))
            height: spiceLabel.implicitHeight + Style.space(10)
            radius: Style.cornerRadius
            color: Util.alpha(Color.popups.text, 0.06)
            border.width: 1
            border.color: Util.alpha(Color.popups.text, 0.22)
            Text {
              id: spiceLabel
              anchors.centerIn: parent
              text: root.tr("btn_shared")
              font.family: root.uiFont
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              color: Color.popups.text
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.goNow("shared")
            }
          }
        }
      }
    }
  }

  IpcHandler {
    target: "winmarchy-vfio"
    function start(): string { root.open("{}"); return "ok" }
    function shared(): string { root.open("{\"mode\":\"shared\"}"); return "ok" }
    function hide(): string { root.dismiss(); return "ok" }
  }
}
