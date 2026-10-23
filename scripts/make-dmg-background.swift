import AppKit
// Reproducible installation guidance, using only system typography and native drawing.
let image = NSImage(size: NSSize(width: 640, height: 400))
image.lockFocus()
NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: 640, height: 400).fill()
func text(_ value: String, y: CGFloat, size: CGFloat, color: NSColor, bold: Bool = false) {
    let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
    (value as NSString).draw(in: NSRect(x: 20, y: y, width: 600, height: 40), withAttributes: [.font: bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size), .foregroundColor: color, .paragraphStyle: paragraph])
}
text("Macventory", y: 325, size: 28, color: .labelColor, bold: true)
text("Know what's on your Mac.", y: 295, size: 15, color: .secondaryLabelColor)
NSColor.systemBlue.setStroke()
let arrow = NSBezierPath(); arrow.lineWidth = 3
arrow.move(to: NSPoint(x: 285, y: 205)); arrow.line(to: NSPoint(x: 355, y: 205))
arrow.move(to: NSPoint(x: 343, y: 217)); arrow.line(to: NSPoint(x: 355, y: 205)); arrow.line(to: NSPoint(x: 343, y: 193)); arrow.stroke()
text("Drag Macventory to Applications", y: 65, size: 17, color: .labelColor, bold: true)
text("Then eject this disk and open Macventory from Applications.", y: 35, size: 12, color: .secondaryLabelColor)
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
