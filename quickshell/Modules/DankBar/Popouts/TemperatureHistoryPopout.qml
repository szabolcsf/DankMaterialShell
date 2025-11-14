import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

DankPopout {
    id: tempHistoryPopout

    property string mode: "cpu" // "cpu" or "gpu"
    property var triggerScreen: null
    property bool isFullscreen: false
    property string selectedTimeRange: "15min" // "15min", "1h", "3h", "6h"

    readonly property real currentTemp: mode === "cpu" ? DgopService.cpuTemperature : (DgopService.availableGpus && DgopService.availableGpus.length > 0 ? DgopService.availableGpus[0].temperature : 0)
    readonly property var fullHistory: mode === "cpu" ? DgopService.cpuTempHistory : DgopService.gpuTempHistory
    readonly property var history: {
        if (!fullHistory || fullHistory.length === 0) return []
        
        let maxPoints = 0
        switch (selectedTimeRange) {
            case "15min": maxPoints = 300; break  // 15 minutes at 3s intervals
            case "1h": maxPoints = 1200; break    // 1 hour
            case "3h": maxPoints = 3600; break    // 3 hours
            case "6h": maxPoints = 7200; break    // 6 hours
            default: maxPoints = 300
        }
        
        // Return last N points
        if (fullHistory.length <= maxPoints) {
            return fullHistory
        }
        return fullHistory.slice(fullHistory.length - maxPoints)
    }
    readonly property int timeRangeSeconds: {
        switch (selectedTimeRange) {
            case "15min": return 900
            case "1h": return 3600
            case "3h": return 10800
            case "6h": return 21600
            default: return 900
        }
    }
    readonly property string deviceName: mode === "cpu" ? (DgopService.cpuModel || "CPU") : (DgopService.availableGpus && DgopService.availableGpus.length > 0 ? DgopService.availableGpus[0].displayName : "GPU")

    function setTriggerPosition(x, y, width, section, screen) {
        triggerX = x
        triggerY = y
        triggerWidth = width
        triggerSection = section
        triggerScreen = screen
    }

    function show() {
        if (!DgopService.dgopAvailable) {
            console.warn("TemperatureHistoryPopout: dgop is not available")
            return
        }
        open()
    }

    function hide() {
        close()
    }

    function toggle(newMode) {
        if (newMode) {
            mode = newMode
        }
        if (!DgopService.dgopAvailable) {
            console.warn("TemperatureHistoryPopout: dgop is not available")
            return
        }
        if (shouldBeVisible) {
            hide()
        } else {
            show()
        }
    }

    function toggleFullscreen() {
        isFullscreen = !isFullscreen
    }

    function calculateMin() {
        if (!history || history.length === 0)
            return 0
        const validTemps = history.filter(t => t > 0)
        if (validTemps.length === 0)
            return 0
        return Math.min(...validTemps)
    }

    function calculateMax() {
        if (!history || history.length === 0)
            return 0
        const validTemps = history.filter(t => t > 0)
        if (validTemps.length === 0)
            return 0
        return Math.max(...validTemps)
    }

    function calculateAvg() {
        if (!history || history.length === 0)
            return 0
        const validTemps = history.filter(t => t > 0)
        if (validTemps.length === 0)
            return 0
        const sum = validTemps.reduce((a, b) => a + b, 0)
        return sum / validTemps.length
    }

    popupWidth: isFullscreen ? screenWidth : 900
    popupHeight: isFullscreen ? screenHeight : 680
    triggerX: Screen.width - 900 - Theme.spacingL
    triggerY: Math.max(26 + SettingsData.dankBarInnerPadding + 4, Theme.barHeight - 4 - (8 - SettingsData.dankBarInnerPadding)) + SettingsData.dankBarSpacing + SettingsData.dankBarBottomGap - 2
    triggerWidth: 55
    positioning: ""
    screen: triggerScreen
    visible: shouldBeVisible
    shouldBeVisible: false

    Behavior on popupWidth {
        NumberAnimation {
            duration: Theme.mediumDuration
            easing.type: Theme.standardEasing
        }
    }

    Behavior on popupHeight {
        NumberAnimation {
            duration: Theme.mediumDuration
            easing.type: Theme.standardEasing
        }
    }

    Component.onCompleted: {
        DgopService.addRef([mode])
        selectedTimeRange = "15min"
    }

    Component.onDestruction: {
        DgopService.removeRef([mode])
    }

    content: Component {
        Rectangle {
            id: tempHistoryContent

            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 0
            clip: true
            antialiasing: true
            smooth: true
            focus: true

            Component.onCompleted: {
                if (tempHistoryPopout.shouldBeVisible) {
                    forceActiveFocus()
                }
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    tempHistoryPopout.close()
                    event.accepted = true
                }
            }

            Connections {
                function onShouldBeVisibleChanged() {
                    if (tempHistoryPopout.shouldBeVisible) {
                        Qt.callLater(() => {
                            tempHistoryContent.forceActiveFocus()
                        })
                    }
                }

                target: tempHistoryPopout
            }

            // Fullscreen toggle button (top right corner)
            DankButton {
                width: 40
                height: 40
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.spacingM
                z: 100
                onClicked: tempHistoryPopout.toggleFullscreen()

                DankIcon {
                    name: isFullscreen ? "fullscreen_exit" : "fullscreen"
                    size: Theme.iconSizeMedium
                    color: Theme.surfaceText
                    anchors.centerIn: parent
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingXL
                spacing: Theme.spacingL

                // Header
                Row {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    DankIcon {
                        name: mode === "cpu" ? "device_thermostat" : "auto_awesome_mosaic"
                        size: Theme.iconSizeMedium
                        color: {
                            if (currentTemp > (mode === "cpu" ? 85 : 80))
                                return Theme.tempDanger
                            if (currentTemp > (mode === "cpu" ? 69 : 65))
                                return Theme.tempWarning
                            return Theme.primary
                        }
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        spacing: Theme.spacingXS

                        StyledText {
                            text: deviceName
                            font.pixelSize: Theme.fontSizeXLarge
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: "Temperature History"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                // Statistics
                Row {
                    Layout.fillWidth: true
                    spacing: Theme.spacingL

                    // Current
                    Rectangle {
                        width: (parent.width - Theme.spacingL * 3) / 4
                        height: 70
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainer

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingM

                            DankIcon {
                                name: mode === "cpu" ? "device_thermostat" : "auto_awesome_mosaic"
                                size: Theme.iconSizeSmall
                                color: {
                                    if (currentTemp > (mode === "cpu" ? 85 : 80))
                                        return Theme.tempDanger
                                    if (currentTemp > (mode === "cpu" ? 69 : 65))
                                        return Theme.tempWarning
                                    return Theme.primary
                                }
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                spacing: 2

                                StyledText {
                                    text: "Current"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }

                                StyledText {
                                    text: currentTemp > 0 ? Math.round(currentTemp) + "°C" : "--°C"
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }
                            }
                        }
                    }

                    // Average
                    Rectangle {
                        width: (parent.width - Theme.spacingL * 3) / 4
                        height: 70
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainer

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingM

                            DankIcon {
                                name: "remove"
                                size: Theme.iconSizeSmall
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                spacing: 2

                                StyledText {
                                    text: "Average"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }

                                StyledText {
                                    text: {
                                        const avgVal = tempHistoryPopout.calculateAvg()
                                        return avgVal > 0 ? Math.round(avgVal) + "°C" : "--°C"
                                    }
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }
                            }
                        }
                    }

                    // Minimum
                    Rectangle {
                        width: (parent.width - Theme.spacingL * 3) / 4
                        height: 70
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainer

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingM

                            DankIcon {
                                name: "arrow_downward"
                                size: Theme.iconSizeSmall
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                spacing: 2

                                StyledText {
                                    text: "Minimum"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }

                                StyledText {
                                    text: {
                                        const minVal = tempHistoryPopout.calculateMin()
                                        return minVal > 0 ? Math.round(minVal) + "°C" : "--°C"
                                    }
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }
                            }
                        }
                    }

                    // Maximum
                    Rectangle {
                        width: (parent.width - Theme.spacingL * 3) / 4
                        height: 70
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainer

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingM

                            DankIcon {
                                name: "arrow_upward"
                                size: Theme.iconSizeSmall
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                spacing: 2

                                StyledText {
                                    text: "Maximum"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }

                                StyledText {
                                    text: {
                                        const maxVal = tempHistoryPopout.calculateMax()
                                        return maxVal > 0 ? Math.round(maxVal) + "°C" : "--°C"
                                    }
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }
                            }
                        }
                    }
                }

                // Chart
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainer

                    TemperatureChart {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        history: tempHistoryPopout.history
                        timeRangeSeconds: tempHistoryPopout.timeRangeSeconds
                        lineColor: mode === "cpu" ? Theme.primary : Theme.secondary
                        currentTemp: tempHistoryPopout.currentTemp
                        label: mode === "cpu" ? "CPU" : "GPU"
                        dangerThreshold: mode === "cpu" ? 85 : 80
                        warningThreshold: mode === "cpu" ? 69 : 65
                    }
                }

                // Legend and time range selector
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingL

                    Row {
                        spacing: Theme.spacingS

                        Rectangle {
                            width: 24
                            height: 3
                            color: mode === "cpu" ? Theme.primary : Theme.secondary
                            radius: 1.5
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: mode === "cpu" ? "CPU Temperature" : "GPU Temperature"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        spacing: Theme.spacingS

                        Rectangle {
                            width: 12
                            height: 12
                            color: Theme.tempWarning
                            opacity: 0.3
                            radius: 2
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Warning >" + (mode === "cpu" ? "69" : "65") + "°C"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        spacing: Theme.spacingS

                        Rectangle {
                            width: 12
                            height: 12
                            color: Theme.tempDanger
                            opacity: 0.3
                            radius: 2
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Danger >" + (mode === "cpu" ? "85" : "80") + "°C"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    // Time range selector
                    DankDropdown {
                        Layout.preferredWidth: 160
                        dropdownWidth: 160
                        compactMode: true
                        currentValue: {
                            switch (selectedTimeRange) {
                                case "15min": return "Last 15 minutes"
                                case "1h": return "Last 1 hour"
                                case "3h": return "Last 3 hours"
                                case "6h": return "Last 6 hours"
                                default: return "Last 15 minutes"
                            }
                        }
                        options: ["Last 15 minutes", "Last 1 hour", "Last 3 hours", "Last 6 hours"]
                        onValueChanged: (value) => {
                            switch (value) {
                                case "Last 15 minutes": selectedTimeRange = "15min"; break
                                case "Last 1 hour": selectedTimeRange = "1h"; break
                                case "Last 3 hours": selectedTimeRange = "3h"; break
                                case "Last 6 hours": selectedTimeRange = "6h"; break
                            }
                        }
                    }
                }
            }
        }
    }
}


