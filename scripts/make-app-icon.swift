// Renders the 1024px app icon: swift scripts/make-app-icon.swift <out.png>
// Then run scripts/make-app-icon.sh to refresh the asset catalog.
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    let ctx = NSGraphicsContext.current!.cgContext

    // macOS icon grid: 824pt body, 100pt margins, continuous-ish corners.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: 186, yRadius: 186)

    ctx.saveGState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    NSColor(calibratedRed: 0.24, green: 0.22, blue: 0.70, alpha: 1).setFill()
    bodyPath.fill()
    ctx.restoreGState()

    ctx.saveGState()
    bodyPath.addClip()
    NSGradient(colors: [
        NSColor(calibratedRed: 0.40, green: 0.47, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.27, green: 0.22, blue: 0.80, alpha: 1),
    ])!.draw(in: body, angle: -90)

    // Faint "remote screen" outline behind the key.
    let screen = NSBezierPath(roundedRect: NSRect(x: 214, y: 470, width: 596, height: 360), xRadius: 44, yRadius: 44)
    screen.lineWidth = 22
    NSColor.white.withAlphaComponent(0.18).setStroke()
    screen.stroke()
    let stand = NSBezierPath(roundedRect: NSRect(x: 452, y: 420, width: 120, height: 22), xRadius: 11, yRadius: 11)
    NSColor.white.withAlphaComponent(0.18).setFill()
    stand.fill()
    ctx.restoreGState()

    // Keycap: lower lip (depth) + top face.
    let lip = NSBezierPath(roundedRect: NSRect(x: 292, y: 186, width: 440, height: 420), xRadius: 92, yRadius: 92)
    ctx.saveGState()
    let keyShadow = NSShadow()
    keyShadow.shadowColor = NSColor(calibratedRed: 0.08, green: 0.05, blue: 0.35, alpha: 0.45)
    keyShadow.shadowBlurRadius = 36
    keyShadow.shadowOffset = NSSize(width: 0, height: -18)
    keyShadow.set()
    NSColor(calibratedRed: 0.80, green: 0.82, blue: 0.93, alpha: 1).setFill()
    lip.fill()
    ctx.restoreGState()

    let face = NSRect(x: 312, y: 226, width: 400, height: 370)
    let facePath = NSBezierPath(roundedRect: face, xRadius: 76, yRadius: 76)
    NSGradient(colors: [
        NSColor.white,
        NSColor(calibratedRed: 0.93, green: 0.94, blue: 0.99, alpha: 1),
    ])!.draw(in: facePath, angle: -90)

    // Dual legend like a Taiwanese keyboard's A key: A (top-left) / ㄇ (bottom-right).
    func draw(_ text: String, font: NSFont, color: NSColor, at point: NSPoint, embolden: CGFloat = 0) {
        NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: color,
            .strokeColor: color, .strokeWidth: -embolden,
        ]).draw(at: point)
    }
    let rounded = NSFont.systemFont(ofSize: 150, weight: .bold).fontDescriptor.withDesign(.rounded)!
    draw("A", font: NSFont(descriptor: rounded, size: 150)!,
         color: NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.45, alpha: 1),
         at: NSPoint(x: 360, y: 400))
    draw("ㄇ", font: NSFont(name: "PingFangTC-Semibold", size: 170) ?? .systemFont(ofSize: 170, weight: .bold),
         color: NSColor(calibratedRed: 0.33, green: 0.30, blue: 0.92, alpha: 1),
         at: NSPoint(x: 500, y: 238), embolden: 9)
    return true
}
let tiff = image.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
