import AppKit
import Foundation

// The source contains a white canvas around its rounded icon artwork.  Crop that
// canvas away and apply an alpha mask so Finder and the Dock do not display it
// as a square behind the app icon.
let source = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Design/Branding/app-icon-source.png"
guard let artwork = NSImage(contentsOfFile: source) else { fatalError("Cannot read official icon source") }
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let iconOutput = CommandLine.arguments.count > 3 ? URL(fileURLWithPath: CommandLine.arguments[3]) : nil
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
// Leave a small safety margin for the magnifier handle at the lower-right edge.
let canvasInset = min(artwork.size.width, artwork.size.height) * 0.07
let artworkRect = NSRect(
    x: canvasInset,
    y: canvasInset,
    width: artwork.size.width - canvasInset * 2,
    height: artwork.size.height - canvasInset * 2
)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.imageInterpolation = .high
        let iconRect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
        // macOS application icons sit inside a clear canvas rather than filling
        // it edge-to-edge. This keeps the Dock size aligned with system apps.
        let visualRect = iconRect.insetBy(dx: CGFloat(pixels) * 0.10, dy: CGFloat(pixels) * 0.10)
        NSColor.clear.setFill()
        iconRect.fill()
        NSBezierPath(roundedRect: visualRect, xRadius: visualRect.width * 0.22, yRadius: visualRect.height * 0.22).addClip()
        artwork.draw(in: visualRect, from: artworkRect, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}

// `iconutil` in the command-line-tools runtime can reject otherwise valid iconsets.
// Build the compact ICNS container directly from the same PNG representations.
if let iconOutput {
    let representations: [(String, String)] = [
        ("ic04", "icon_16x16.png"),
        ("ic11", "icon_16x16@2x.png"),
        ("ic05", "icon_32x32.png"),
        ("ic12", "icon_32x32@2x.png"),
        ("ic07", "icon_128x128.png"),
        ("ic13", "icon_128x128@2x.png"),
        ("ic08", "icon_256x256.png"),
        ("ic14", "icon_256x256@2x.png"),
        ("ic09", "icon_512x512.png"),
        ("ic10", "icon_512x512@2x.png")
    ]
    func uint32Data(_ value: Int) -> Data {
        var bigEndian = UInt32(value).bigEndian
        return Data(bytes: &bigEndian, count: MemoryLayout<UInt32>.size)
    }
    var chunks = Data()
    for (type, filename) in representations {
        let image = try Data(contentsOf: directory.appendingPathComponent(filename))
        chunks.append(type.data(using: .ascii)!)
        chunks.append(uint32Data(image.count + 8))
        chunks.append(image)
    }
    var icon = Data("icns".utf8)
    icon.append(uint32Data(chunks.count + 8))
    icon.append(chunks)
    try icon.write(to: iconOutput)
}
