// Generates the WattBar app icon (1024×1024 master PNG).
// Run: swift scripts/gen-icon.swift <output.png>
import AppKit

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
let canvas = 1024.0

let image = NSImage(size: NSSize(width: canvas, height: canvas))
image.lockFocus()

// macOS icon grid: squircle occupies ~824pt of a 1024pt canvas.
let inset = 100.0
let rect = NSRect(x: inset, y: inset, width: canvas - 2 * inset, height: canvas - 2 * inset)
let squircle = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)

let top = NSColor(calibratedRed: 0.23, green: 0.24, blue: 0.27, alpha: 1)
let bottom = NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.11, alpha: 1)
NSGradient(starting: top, ending: bottom)?.draw(in: squircle, angle: -90)

// Subtle inner highlight along the top edge.
squircle.addClip()
let highlight = NSGradient(starting: NSColor.white.withAlphaComponent(0.10),
                           ending: NSColor.white.withAlphaComponent(0.0))
highlight?.draw(in: NSRect(x: inset, y: rect.maxY - 220, width: rect.width, height: 220), angle: -90)

// Bolt symbol, tinted system yellow.
let config = NSImage.SymbolConfiguration(pointSize: 440, weight: .semibold)
if let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let tinted = NSImage(size: bolt.size)
    tinted.lockFocus()
    bolt.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
    NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.04, alpha: 1).set()
    NSRect(origin: .zero, size: bolt.size).fill(using: .sourceAtop)
    tinted.unlockFocus()

    let target = NSRect(x: (canvas - bolt.size.width) / 2,
                        y: (canvas - bolt.size.height) / 2,
                        width: bolt.size.width,
                        height: bolt.size.height)
    tinted.draw(in: target)
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to render icon\n", stderr)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
