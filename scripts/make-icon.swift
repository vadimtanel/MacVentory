import AppKit
import Foundation

// Resize the owner's original artwork without cropping, redrawing or changing proportions.
let source = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Design/Branding/app-icon-source.png"
guard let artwork = NSImage(contentsOfFile: source) else { fatalError("Cannot read official icon source") }
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.imageInterpolation = .high
        let fit = min(CGFloat(pixels) / artwork.size.width, CGFloat(pixels) / artwork.size.height)
        let size = NSSize(width: artwork.size.width * fit, height: artwork.size.height * fit)
        artwork.draw(in: NSRect(x: (CGFloat(pixels) - size.width) / 2, y: (CGFloat(pixels) - size.height) / 2, width: size.width, height: size.height), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
