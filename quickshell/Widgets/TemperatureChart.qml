import QtQuick
import qs.Common

Canvas {
    id: root

    property var history: []
    property int timeRangeSeconds: 900 // Default 15 minutes
    property color lineColor: Theme.primary
    property real minTemp: 20
    property real maxTemp: 100
    property string label: "Temperature"
    property real currentTemp: 0
    property real dangerThreshold: 85
    property real warningThreshold: 69

    implicitWidth: 400
    implicitHeight: 200

    renderTarget: Canvas.FramebufferObject
    renderStrategy: Canvas.Cooperative
    antialiasing: true

    onHistoryChanged: requestPaint()
    onTimeRangeSecondsChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onMinTempChanged: requestPaint()
    onMaxTempChanged: requestPaint()
    onCurrentTempChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    Connections {
        target: Theme
        function onPrimaryChanged() { root.requestPaint() }
        function onSurfaceTextChanged() { root.requestPaint() }
        function onOutlineChanged() { root.requestPaint() }
        function onTempDangerChanged() { root.requestPaint() }
        function onTempWarningChanged() { root.requestPaint() }
    }

    onPaint: {
        const ctx = getContext("2d")
        if (!ctx) return

        const w = width
        const h = height
        const padding = 40
        const chartW = w - padding * 2
        const chartH = h - padding * 2

        // Clear canvas
        ctx.clearRect(0, 0, w, h)

        if (!history || history.length === 0) {
            return
        }

        // Calculate temperature range
        let actualMin = minTemp
        let actualMax = maxTemp
        
        if (history.length > 0) {
            const temps = history.filter(t => t > 0)
            if (temps.length > 0) {
                actualMin = Math.max(0, Math.min(...temps) - 10)
                actualMax = Math.max(...temps) + 10
            }
        }

        const tempRange = actualMax - actualMin

        function tempToY(temp) {
            if (tempRange === 0) return chartH / 2 + padding
            return padding + chartH - ((temp - actualMin) / tempRange) * chartH
        }

        function indexToX(index, total) {
            if (total <= 1) return padding + chartW
            
            // Calculate actual time span of data (oldest to newest)
            const dataTimeSpan = (total - 1) * 3 // seconds
            
            // Calculate position based on time range
            // The last data point is at "now" (right edge)
            // Earlier points are positioned based on their actual time offset
            const pointSecondsAgo = (total - 1 - index) * 3
            const progressFromEnd = pointSecondsAgo / timeRangeSeconds
            
            return padding + chartW - (progressFromEnd * chartW)
        }

        // Draw background temperature zones
        ctx.globalAlpha = 0.1

        // Danger zone (red)
        if (dangerThreshold < actualMax) {
            const y = tempToY(dangerThreshold)
            ctx.fillStyle = Theme.tempDanger
            ctx.fillRect(padding, padding, chartW, y - padding)
        }

        // Warning zone (yellow)
        if (warningThreshold < actualMax && warningThreshold > actualMin) {
            const yTop = tempToY(Math.min(dangerThreshold, actualMax))
            const yBottom = tempToY(warningThreshold)
            ctx.fillStyle = Theme.tempWarning
            ctx.fillRect(padding, yTop, chartW, yBottom - yTop)
        }

        ctx.globalAlpha = 1.0

        // Draw grid lines
        ctx.strokeStyle = Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
        ctx.lineWidth = 1

        // Horizontal grid lines (temperature)
        const tempSteps = 5
        for (let i = 0; i <= tempSteps; i++) {
            const temp = actualMin + (tempRange / tempSteps) * i
            const y = tempToY(temp)
            
            ctx.beginPath()
            ctx.moveTo(padding, y)
            ctx.lineTo(padding + chartW, y)
            ctx.stroke()
        }

        // Draw temperature line
        ctx.strokeStyle = lineColor
        ctx.lineWidth = 2
        ctx.lineCap = "round"
        ctx.lineJoin = "round"

        ctx.beginPath()
        let firstPoint = true
        
        for (let i = 0; i < history.length; i++) {
            const temp = history[i]
            if (temp <= 0) continue

            const x = indexToX(i, history.length)
            const y = tempToY(temp)

            if (firstPoint) {
                ctx.moveTo(x, y)
                firstPoint = false
            } else {
                ctx.lineTo(x, y)
            }
        }
        ctx.stroke()

        // Draw gradient fill under line
        if (!firstPoint) {
            // Close the path to create filled area
            const lastX = indexToX(history.length - 1, history.length)
            const firstX = indexToX(0, history.length)
            
            ctx.lineTo(lastX, padding + chartH)
            ctx.lineTo(firstX, padding + chartH)
            ctx.closePath()

            const gradient = ctx.createLinearGradient(0, padding, 0, padding + chartH)
            gradient.addColorStop(0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.3))
            gradient.addColorStop(1, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.05))
            ctx.fillStyle = gradient
            ctx.fill()
        }

        // Draw current temperature marker
        if (currentTemp > 0 && history.length > 0) {
            const x = indexToX(history.length - 1, history.length)
            const y = tempToY(currentTemp)

            // Draw circle
            ctx.fillStyle = lineColor
            ctx.beginPath()
            ctx.arc(x, y, 4, 0, Math.PI * 2)
            ctx.fill()

            // Draw outer glow
            ctx.strokeStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.5)
            ctx.lineWidth = 2
            ctx.beginPath()
            ctx.arc(x, y, 6, 0, Math.PI * 2)
            ctx.stroke()
        }

        // Draw axis labels
        ctx.fillStyle = Theme.surfaceText
        ctx.font = "10px sans-serif"
        ctx.textAlign = "right"
        ctx.textBaseline = "middle"

        // Temperature labels
        for (let i = 0; i <= tempSteps; i++) {
            const temp = actualMin + (tempRange / tempSteps) * i
            const y = tempToY(temp)
            ctx.fillText(Math.round(temp) + "°", padding - 5, y)
        }

        // Time labels
        ctx.textAlign = "center"
        ctx.textBaseline = "top"
        ctx.fillStyle = Theme.surfaceVariantText
        
        const now = new Date()
        const numTimeLabels = Math.min(5, Math.max(2, Math.floor(chartW / 100)))
        
        for (let i = 0; i < numTimeLabels; i++) {
            // Calculate time position based on timeRangeSeconds, not history.length
            const progressRatio = i / (numTimeLabels - 1)
            const secondsAgo = timeRangeSeconds - (timeRangeSeconds * progressRatio)
            const time = new Date(now.getTime() - secondsAgo * 1000)
            const hours = String(time.getHours()).padStart(2, '0')
            const minutes = String(time.getMinutes()).padStart(2, '0')
            const timeStr = hours + ":" + minutes
            
            // Position on chart
            const x = padding + (chartW * progressRatio)
            ctx.fillText(timeStr, x, padding + chartH + 5)
        }
    }
}

