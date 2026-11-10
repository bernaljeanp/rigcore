import QtQuick
import QtQuick.Shapes

// Fondo con resplandores difusos que se tiñen con el modo activo.
Item {
    id: bg
    property color accent: "#8C7CFF"
    property color second: "#38BDF8"
    clip: true

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#0B0C12" }
            GradientStop { position: 1; color: "#07080C" }
        }
    }

    component Glow: Shape {
        preferredRendererType: Shape.GeometryRenderer
        id: glow
        property color tint
        property real radius: 420
        width: radius * 2; height: radius * 2
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: glow.radius; centerY: glow.radius
                centerRadius: glow.radius
                focalX: centerX; focalY: centerY
                GradientStop { position: 0; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, 0.22) }
                GradientStop { position: 0.45; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, 0.07) }
                GradientStop { position: 1; color: "transparent" }
            }
            PathRectangle { width: glow.width; height: glow.height }
        }
    }

    Glow {
        id: g1
        tint: bg.accent
        radius: 520
        x: bg.width * 0.62 - radius
        y: -radius * 0.55
    }
    Glow {
        tint: bg.second
        radius: 460
        x: -radius * 0.6
        y: bg.height - radius * 1.1
    }

    // Rejilla de puntos muy sutil.
    Canvas {
        anchors.fill: parent
        opacity: 0.5
        onPaint: {
            var ctx = getContext("2d")
            ctx.fillStyle = "rgba(255,255,255,0.035)"
            for (var x = 12; x < width; x += 26)
                for (var y = 12; y < height; y += 26)
                    ctx.fillRect(x, y, 1, 1)
        }
    }
}
