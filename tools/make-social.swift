// Génère docs/social-preview.png (1280 × 640) : l'image affichée quand le lien du dépôt est partagé.
// À téléverser dans Settings → General → Social preview du dépôt GitHub.
// Usage : swift tools/make-social.swift   (après tools/make-icon.swift)
import AppKit

let W: CGFloat = 1280, H: CGFloat = 640
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let icon = NSImage(contentsOf: root.appendingPathComponent("Resources/AppIcon.png"))!

func text(_ s: String, font: NSFont, color: NSColor, at p: CGPoint, kern: CGFloat = 0) -> CGSize {
    let str = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color, .kern: kern])
    str.draw(at: p)
    return str.size()
}

let image = NSImage(size: NSSize(width: W, height: H), flipped: false) { _ in
    let ctx = NSGraphicsContext.current!.cgContext

    // Fond : même dégradé que l'icône, en diagonale
    let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        NSColor(red: 0.36, green: 0.33, blue: 0.95, alpha: 1).cgColor,
        NSColor(red: 0.08, green: 0.07, blue: 0.22, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: H), end: CGPoint(x: W, y: 0), options: [])

    // Icône (le PNG inclut déjà ombre et marge)
    icon.draw(in: NSRect(x: 40, y: (H - 460) / 2, width: 460, height: 460))

    let left: CGFloat = 540
    let white = NSColor.white

    _ = text("HiddenBar", font: .systemFont(ofSize: 96, weight: .heavy), color: white, at: CGPoint(x: left - 4, y: 388), kern: -2)
    _ = text("Hide menu bar icons in one click.", font: .systemFont(ofSize: 34, weight: .regular),
             color: white.withAlphaComponent(0.85), at: CGPoint(x: left, y: 330))
    _ = text("Native Swift · works on macOS 27", font: .systemFont(ofSize: 34, weight: .regular),
             color: white.withAlphaComponent(0.85), at: CGPoint(x: left, y: 286))

    // Pastille commande brew
    let cmd = "brew install --cask noahsmo/tap/hiddenbar"
    let mono = NSFont.monospacedSystemFont(ofSize: 25, weight: .medium)
    let cmdSize = NSAttributedString(string: cmd, attributes: [.font: mono]).size()
    let chip = CGRect(x: left, y: 180, width: cmdSize.width + 52, height: 66)
    ctx.addPath(CGPath(roundedRect: chip, cornerWidth: 18, cornerHeight: 18, transform: nil))
    ctx.setFillColor(NSColor(red: 0.05, green: 0.04, blue: 0.14, alpha: 0.85).cgColor)
    ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: chip, cornerWidth: 18, cornerHeight: 18, transform: nil))
    ctx.setStrokeColor(white.withAlphaComponent(0.18).cgColor)
    ctx.setLineWidth(2)
    ctx.strokePath()
    _ = text(cmd, font: mono, color: white, at: CGPoint(x: chip.minX + 26, y: chip.midY - cmdSize.height / 2))

    // Petite barre des menus : icônes qui s'estompent → séparateur → chevron
    let barY: CGFloat = 96, dot: CGFloat = 26
    for (i, alpha) in [0.12, 0.25, 0.45, 0.7].enumerated() {
        ctx.setFillColor(white.withAlphaComponent(alpha).cgColor)
        ctx.fillEllipse(in: CGRect(x: left + CGFloat(i) * 48, y: barY - dot / 2, width: dot, height: dot))
    }
    let pipeX = left + 4 * 48 + 4
    ctx.addPath(CGPath(roundedRect: CGRect(x: pipeX, y: barY - 20, width: 6, height: 40), cornerWidth: 3, cornerHeight: 3, transform: nil))
    ctx.setFillColor(white.cgColor)
    ctx.fillPath()
    ctx.setStrokeColor(white.cgColor)
    ctx.setLineWidth(7)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    let cx = pipeX + 44
    ctx.move(to: CGPoint(x: cx + 9, y: barY + 17))
    ctx.addLine(to: CGPoint(x: cx - 9, y: barY))
    ctx.addLine(to: CGPoint(x: cx + 9, y: barY - 17))
    ctx.strokePath()
    return true
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: NSRect(x: 0, y: 0, width: W, height: H))
NSGraphicsContext.restoreGraphicsState()

let out = root.appendingPathComponent("docs/social-preview.png")
try! FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("OK → docs/social-preview.png (1280 × 640)")
print("À téléverser : https://github.com/NoahSmo/HiddenBar/settings → General → Social preview")
