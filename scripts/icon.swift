import AppKit
import Foundation
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
NSColor(calibratedRed: 0.045, green: 0.08, blue: 0.09, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: 220, yRadius: 220).fill()
NSColor(calibratedRed: 0.32, green: 0.94, blue: 0.72, alpha: 1).setFill()
for x in [244.0, 536.0] {
    for y in [244.0, 536.0] {
        NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 244, height: 244), xRadius: 58, yRadius: 58).fill()
    }
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: output, options: .withoutOverwriting)
