import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let outputDirectory = root
    .appendingPathComponent("StoreCheckIn", isDirectory: true)
    .appendingPathComponent("Assets.xcassets", isDirectory: true)
    .appendingPathComponent("AppIcon.appiconset", isDirectory: true)

let outputs: [(name: String, size: Int)] = [
    ("iphone-notification-20@2x.png", 40),
    ("iphone-notification-20@3x.png", 60),
    ("iphone-settings-29@2x.png", 58),
    ("iphone-settings-29@3x.png", 87),
    ("iphone-spotlight-40@2x.png", 80),
    ("iphone-spotlight-40@3x.png", 120),
    ("iphone-app-60@2x.png", 120),
    ("iphone-app-60@3x.png", 180),
    ("ipad-notification-20@1x.png", 20),
    ("ipad-notification-20@2x.png", 40),
    ("ipad-settings-29@1x.png", 29),
    ("ipad-settings-29@2x.png", 58),
    ("ipad-spotlight-40@1x.png", 40),
    ("ipad-spotlight-40@2x.png", 80),
    ("ipad-app-76@1x.png", 76),
    ("ipad-app-76@2x.png", 152),
    ("ipad-pro-83.5@2x.png", 167),
    ("Icon-1024.png", 1024)
]

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func fill(_ rect: CGRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    roundedRect(rect, radius: radius).fill()
}

func stroke(_ rect: CGRect, radius: CGFloat, color: NSColor, lineWidth: CGFloat) {
    color.setStroke()
    let path = roundedRect(rect, radius: radius)
    path.lineWidth = lineWidth
    path.stroke()
}

func circle(_ rect: CGRect, color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: rect).fill()
}

func line(from: CGPoint, to: CGPoint, width: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.move(to: from)
    path.line(to: to)
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    color.setStroke()
    path.stroke()
}

func withShadow(color: NSColor, blur: CGFloat, x: CGFloat, y: CGFloat, draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: x, height: y)
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

func checkmark(in rect: CGRect, lineWidth: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.minY + rect.height * 0.52))
    path.line(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.30))
    path.line(to: CGPoint(x: rect.minX + rect.width * 0.78, y: rect.minY + rect.height * 0.68))
    path.lineWidth = lineWidth
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    color.setStroke()
    path.stroke()
}

func renderIcon(edge: Int, destination: URL) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: edge,
        pixelsHigh: edge,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "IconGenerator", code: 1)
    }

    bitmap.size = NSSize(width: edge, height: edge)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "IconGenerator", code: 2)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let edge = CGFloat(edge)
    let canvas = CGRect(x: 0, y: 0, width: edge, height: edge)

    let shellRect = canvas.insetBy(dx: edge * 0.01, dy: edge * 0.01)
    let shellPath = roundedRect(shellRect, radius: edge * 0.12)

    let shellGradient = NSGradient(colors: [
        rgba(139, 227, 249),
        rgba(63, 140, 241),
        rgba(23, 39, 170),
        rgba(4, 72, 100)
    ])!
    shellGradient.draw(in: shellPath, angle: -34)
    stroke(shellRect, radius: edge * 0.12, color: rgba(124, 214, 255, 0.50), lineWidth: max(1, edge * 0.004))

    let innerGlow = CGRect(x: shellRect.minX + edge * 0.02, y: shellRect.maxY - edge * 0.16, width: edge * 0.18, height: edge * 0.12)
    circle(innerGlow, color: rgba(255, 255, 255, 0.14))

    let clockCenter = CGPoint(x: edge * 0.50, y: edge * 0.64)
    let ringRadius = edge * 0.31
    let faceRadius = edge * 0.27
    let ringRect = CGRect(x: clockCenter.x - ringRadius, y: clockCenter.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2)
    let faceRect = CGRect(x: clockCenter.x - faceRadius, y: clockCenter.y - faceRadius, width: faceRadius * 2, height: faceRadius * 2)

    withShadow(color: rgba(8, 18, 54, 0.35), blur: edge * 0.03, x: edge * 0.012, y: -edge * 0.01) {
        circle(ringRect, color: rgba(244, 245, 248))
    }

    let faceGradient = NSGradient(colors: [
        rgba(255, 255, 255),
        rgba(241, 243, 248)
    ])!
    faceGradient.draw(in: NSBezierPath(ovalIn: faceRect), angle: -90)

    let faceOutline = NSBezierPath(ovalIn: faceRect)
    faceOutline.lineWidth = max(1, edge * 0.008)
    rgba(60, 164, 203, 0.95).setStroke()
    faceOutline.stroke()

    for step in 0..<12 {
        let angle = CGFloat(step) * (.pi / 6) - (.pi / 2)
        let start = CGPoint(
            x: clockCenter.x + cos(angle) * faceRadius * 0.80,
            y: clockCenter.y + sin(angle) * faceRadius * 0.80
        )
        let end = CGPoint(
            x: clockCenter.x + cos(angle) * faceRadius * 0.92,
            y: clockCenter.y + sin(angle) * faceRadius * 0.92
        )
        line(from: start, to: end, width: max(1, edge * 0.009), color: rgba(51, 167, 198))
    }

    line(
        from: clockCenter,
        to: CGPoint(x: clockCenter.x - faceRadius * 0.58, y: clockCenter.y),
        width: max(1.5, edge * 0.036),
        color: rgba(40, 144, 186)
    )
    line(
        from: clockCenter,
        to: CGPoint(x: clockCenter.x, y: clockCenter.y + faceRadius * 0.62),
        width: max(1.5, edge * 0.036),
        color: rgba(40, 144, 186)
    )
    circle(CGRect(x: clockCenter.x - edge * 0.03, y: clockCenter.y - edge * 0.03, width: edge * 0.06, height: edge * 0.06), color: rgba(54, 154, 190))
    circle(CGRect(x: clockCenter.x - edge * 0.015, y: clockCenter.y - edge * 0.015, width: edge * 0.03, height: edge * 0.03), color: rgba(236, 240, 245))

    let cardRect = CGRect(x: edge * 0.18, y: edge * 0.14, width: edge * 0.64, height: edge * 0.37)
    withShadow(color: rgba(10, 18, 50, 0.32), blur: edge * 0.03, x: edge * 0.012, y: -edge * 0.014) {
        fill(cardRect, radius: edge * 0.045, color: rgba(249, 249, 251))
    }
    stroke(cardRect, radius: edge * 0.045, color: rgba(58, 161, 200), lineWidth: max(1, edge * 0.006))

    let stripRect = CGRect(x: cardRect.minX, y: cardRect.maxY - edge * 0.09, width: cardRect.width, height: edge * 0.09)
    let stripGradient = NSGradient(colors: [
        rgba(106, 238, 229),
        rgba(63, 220, 206)
    ])!
    stripGradient.draw(in: roundedRect(stripRect, radius: edge * 0.035), angle: 0)

    let clipRect = CGRect(x: edge * 0.40, y: cardRect.maxY - edge * 0.055, width: edge * 0.20, height: edge * 0.10)
    let clipGradient = NSGradient(colors: [
        rgba(93, 208, 233),
        rgba(49, 129, 195)
    ])!
    clipGradient.draw(in: roundedRect(clipRect, radius: edge * 0.05), angle: -90)
    fill(CGRect(x: edge * 0.465, y: cardRect.maxY - edge * 0.03, width: edge * 0.07, height: edge * 0.04), radius: edge * 0.02, color: rgba(246, 246, 250))
    stroke(CGRect(x: edge * 0.492, y: cardRect.maxY - edge * 0.008, width: edge * 0.016, height: edge * 0.028), radius: edge * 0.008, color: rgba(246, 246, 250), lineWidth: max(1, edge * 0.005))

    circle(CGRect(x: cardRect.minX + edge * 0.11, y: cardRect.minY + edge * 0.16, width: edge * 0.11, height: edge * 0.11), color: rgba(59, 186, 208))
    fill(CGRect(x: cardRect.minX + edge * 0.06, y: cardRect.minY + edge * 0.05, width: edge * 0.22, height: edge * 0.10), radius: edge * 0.045, color: rgba(44, 146, 188))
    fill(CGRect(x: cardRect.minX + edge * 0.21, y: cardRect.minY + edge * 0.08, width: edge * 0.04, height: edge * 0.04), radius: edge * 0.007, color: rgba(241, 242, 247))
    stroke(CGRect(x: cardRect.minX + edge * 0.225, y: cardRect.minY + edge * 0.115, width: edge * 0.010, height: edge * 0.020), radius: edge * 0.005, color: rgba(241, 242, 247), lineWidth: max(1, edge * 0.004))

    let infoWidths: [CGFloat] = [0.21, 0.20, 0.10]
    for (index, proportion) in infoWidths.enumerated() {
        fill(
            CGRect(
                x: cardRect.minX + edge * 0.32,
                y: cardRect.maxY - edge * (0.13 + CGFloat(index) * 0.048),
                width: edge * proportion,
                height: max(1, edge * 0.010)
            ),
            radius: edge * 0.005,
            color: rgba(39, 156, 187)
        )
    }

    let badgeRect = CGRect(x: edge * 0.66, y: edge * 0.10, width: edge * 0.24, height: edge * 0.24)
    withShadow(color: rgba(8, 18, 52, 0.35), blur: edge * 0.025, x: edge * 0.012, y: -edge * 0.012) {
        let badgeGradient = NSGradient(colors: [
            rgba(126, 240, 220),
            rgba(19, 201, 159)
        ])!
        badgeGradient.draw(in: NSBezierPath(ovalIn: badgeRect), angle: -90)
    }
    checkmark(in: badgeRect.insetBy(dx: edge * 0.04, dy: edge * 0.04), lineWidth: max(2, edge * 0.024), color: rgba(248, 248, 250))

    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGenerator", code: 3)
    }
    try data.write(to: destination)
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
for output in outputs {
    try renderIcon(edge: output.size, destination: outputDirectory.appendingPathComponent(output.name))
}

print("Updated app icon assets in \(outputDirectory.path)")
