import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    readonly property date releaseMoment: new Date(2026, 10, 19, 0, 0, 0)
    readonly property real screenScale: Screen.height / 1440
    readonly property color outlineColor: "#1d0231"
    readonly property int outlineDirections: 16
    readonly property var weekdayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    property date now: new Date()
    readonly property int remainingSeconds: Math.max(0, Math.floor((releaseMoment - now) / 1000))

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    function scaled(pixels) {
        return Math.max(1, Math.round(pixels * screenScale))
    }

    function twoDigits(value) {
        return String(value).padStart(2, "0")
    }

    function formatClockTime(moment) {
        return [moment.getHours(), moment.getMinutes(), moment.getSeconds()].map(twoDigits).join(":")
    }

    function formatWeekdayAndDate(moment) {
        const date = [twoDigits(moment.getDate()), twoDigits(moment.getMonth() + 1), moment.getFullYear()].join("/")
        return weekdayNames[moment.getDay()] + " " + date
    }

    function remainingUnits() {
        return {
            days: Math.floor(remainingSeconds / 86400),
            hours: Math.floor((remainingSeconds % 86400) / 3600),
            minutes: Math.floor((remainingSeconds % 3600) / 60),
            seconds: remainingSeconds % 60
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    component OutlinedText: Item {
        id: outlinedText
        property string text
        property int pixelSize
        property int outlineWidth
        property real letterSpacing: 0
        implicitWidth: fillText.implicitWidth
        implicitHeight: fillText.implicitHeight

        Repeater {
            model: root.outlineDirections
            Text {
                readonly property real angle: index / root.outlineDirections * 2 * Math.PI
                x: Math.round(Math.cos(angle) * outlinedText.outlineWidth)
                y: Math.round(Math.sin(angle) * outlinedText.outlineWidth)
                text: outlinedText.text
                color: root.outlineColor
                font.family: "Pricedown"
                font.pixelSize: outlinedText.pixelSize
                font.letterSpacing: outlinedText.letterSpacing
            }
        }

        Text {
            id: fillText
            text: outlinedText.text
            color: "#ffffff"
            font.family: "Pricedown"
            font.pixelSize: outlinedText.pixelSize
            font.letterSpacing: outlinedText.letterSpacing
        }
    }

    component CountdownUnit: ColumnLayout {
        property string value
        property string caption
        spacing: root.scaled(10)
        Layout.minimumWidth: root.scaled(130)

        OutlinedText {
            Layout.alignment: Qt.AlignHCenter
            text: parent.value
            pixelSize: root.scaled(120)
            outlineWidth: root.scaled(4)
        }

        OutlinedText {
            Layout.alignment: Qt.AlignHCenter
            text: parent.caption
            pixelSize: root.scaled(18)
            outlineWidth: root.scaled(2)
            letterSpacing: root.scaled(3)
        }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: root.remainingSeconds > 0 ? countdownRow.implicitWidth : clockColumn.implicitWidth
        Layout.preferredHeight: root.remainingSeconds > 0 ? countdownRow.implicitHeight : clockColumn.implicitHeight

        RowLayout {
            id: countdownRow
            visible: root.remainingSeconds > 0
            spacing: root.scaled(38)
            readonly property var units: root.remainingUnits()

            CountdownUnit { value: root.twoDigits(countdownRow.units.days); caption: "DAYS" }
            CountdownUnit { value: root.twoDigits(countdownRow.units.hours); caption: "HOURS" }
            CountdownUnit { value: root.twoDigits(countdownRow.units.minutes); caption: "MINUTES" }
            CountdownUnit { value: root.twoDigits(countdownRow.units.seconds); caption: "SECONDS" }
        }

        ColumnLayout {
            id: clockColumn
            visible: root.remainingSeconds === 0
            spacing: root.scaled(10)

            OutlinedText {
                text: root.formatClockTime(root.now)
                pixelSize: root.scaled(120)
                outlineWidth: root.scaled(4)
            }

            OutlinedText {
                text: root.formatWeekdayAndDate(root.now)
                pixelSize: root.scaled(36)
                outlineWidth: root.scaled(2)
                letterSpacing: root.scaled(3)
            }
        }
    }
}
