// Renders Resources/AppIcon.icns. Run: swift scripts/make-icon.swift
import AppKit

func render(_ size: Int) -> Data {
    let s = CGFloat(size)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()
    let inset = s * 0.1
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: rect, xRadius: s * 0.18, yRadius: s * 0.18)
    NSGradient(starting: NSColor(red: 0.98, green: 0.36, blue: 0.30, alpha: 1),
               ending: NSColor(red: 0.62, green: 0.12, blue: 0.42, alpha: 1))!.draw(in: path, angle: -60)
    // A strip of film with a gap cut out of it.
    NSColor.white.withAlphaComponent(0.95).setFill()
    let stripH = s * 0.22, y = s * 0.5 - stripH / 2
    NSBezierPath(roundedRect: NSRect(x: rect.minX + s * 0.08, y: y, width: s * 0.22, height: stripH), xRadius: s * 0.02, yRadius: s * 0.02).fill()
    NSBezierPath(roundedRect: NSRect(x: rect.maxX - s * 0.30, y: y, width: s * 0.22, height: stripH), xRadius: s * 0.02, yRadius: s * 0.02).fill()
    if let sym = NSImage(systemSymbolName: "scissors", accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: s * 0.30, weight: .bold)) {
        let tinted = NSImage(size: sym.size, flipped: false) { r in
            sym.draw(in: r); NSColor.black.set(); r.fill(using: .sourceAtop); return true
        }
        let w = tinted.size.width, h = tinted.size.height
        tinted.draw(in: NSRect(x: s / 2 - w / 2, y: s / 2 - h / 2, width: w, height: h))
    }
    img.unlockFocus()
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let set = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: set)
try! fm.createDirectory(at: set, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: set.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: set.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", set.path, "-o", "Resources/AppIcon.icns"]
try! p.run(); p.waitUntilExit()
print(p.terminationStatus == 0 ? "wrote Resources/AppIcon.icns" : "iconutil failed")
