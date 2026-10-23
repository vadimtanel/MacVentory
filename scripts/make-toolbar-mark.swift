import AppKit
import Foundation

// Deterministic UI-only derivative: crop to the official foreground artwork,
// then fade near-white pixels to alpha. Original artwork and Dock ICNS are untouched.
guard let image = NSImage(contentsOfFile: "Design/Branding/app-icon-source.png") else { fatalError("Missing official source") }
let size = 256
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSGraphicsContext.current?.imageInterpolation = .high
// NSImage drawing coordinates originate at bottom left; source is1254×1254.
image.draw(in: NSRect(x: 0, y: 16, width: 256, height: 224), from: NSRect(x: 190, y: 194, width: 960, height: 840), operation: .copy, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
for y in 0..<size {
    for x in 0..<size {
        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
        let minimum = min(color.redComponent, color.greenComponent, color.blueComponent)
        let alpha = min(1, max(0, (0.97 - minimum) / 0.28)) * color.alphaComponent
        bitmap.setColor(NSColor(deviceRed: color.redComponent, green: color.greenComponent, blue: color.blueComponent, alpha: alpha), atX: x, y: y)
    }
}
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "Resources/ToolbarMark.png"))
