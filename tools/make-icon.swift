// Génère Resources/AppIcon.icns
// Usage : swift tools/make-icon.swift
import AppKit

let size: CGFloat = 1024

func render() -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

        // Squircle macOS (grille Big Sur : 824 pt de contenu, rayon ~185)
        let inset: CGFloat = 100
        let tile = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
        let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

        // Ombre portée
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
        ctx.addPath(tilePath)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        // Fond dégradé indigo → nuit
        ctx.saveGState()
        ctx.addPath(tilePath)
        ctx.clip()
        let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
            NSColor(red: 0.36, green: 0.33, blue: 0.95, alpha: 1).cgColor,
            NSColor(red: 0.08, green: 0.07, blue: 0.22, alpha: 1).cgColor,
        ] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])

        // Barre des menus « verre »
        let bar = CGRect(x: tile.minX + 90, y: size / 2 - 85, width: tile.width - 180, height: 170)
        let barPath = CGPath(roundedRect: bar, cornerWidth: 85, cornerHeight: 85, transform: nil)
        ctx.addPath(barPath)
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.14).cgColor)
        ctx.fillPath()
        ctx.addPath(barPath)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.30).cgColor)
        ctx.setLineWidth(4)
        ctx.strokePath()

        // Icônes qui disparaissent (de plus en plus transparentes vers la gauche)
        let cy = bar.midY
        let dots: [(x: CGFloat, alpha: CGFloat)] = [(bar.minX + 95, 0.12), (bar.minX + 205, 0.30), (bar.minX + 315, 0.60)]
        for d in dots {
            ctx.setFillColor(NSColor.white.withAlphaComponent(d.alpha).cgColor)
            ctx.fillEllipse(in: CGRect(x: d.x - 38, y: cy - 38, width: 76, height: 76))
        }

        // Séparateur « | »
        let pipe = CGRect(x: bar.minX + 408, y: cy - 58, width: 16, height: 116)
        ctx.addPath(CGPath(roundedRect: pipe, cornerWidth: 8, cornerHeight: 8, transform: nil))
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.95).cgColor)
        ctx.fillPath()

        // Chevron ‹
        let cx = bar.maxX - 110
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(26)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.move(to: CGPoint(x: cx + 26, y: cy + 52))
        ctx.addLine(to: CGPoint(x: cx - 26, y: cy))
        ctx.addLine(to: CGPoint(x: cx + 26, y: cy - 52))
        ctx.strokePath()

        ctx.restoreGState()
        return true
    }
}

func png(_ image: NSImage, _ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let image = render()
for base in [16, 32, 128, 256, 512] {
    try! png(image, base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! png(image, base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try! png(image, 1024).write(to: root.appendingPathComponent("Resources/AppIcon.png"))

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try! task.run()
task.waitUntilExit()
print("OK → Resources/AppIcon.icns")
