import AppKit
import Foundation

// Original vector geometry, rasterized for the required iOS app-icon asset.
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(srgbRed: 0x25 / 255.0, green: 0x3E / 255.0, blue: 0x32 / 255.0, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
let ivory = NSColor(srgbRed: 0xF7 / 255.0, green: 0xF6 / 255.0, blue: 0xF0 / 255.0, alpha: 1)
ivory.setStroke()
let arch = NSBezierPath()
arch.move(to: NSPoint(x: 286, y: 236)); arch.line(to: NSPoint(x: 286, y: 566))
arch.curve(to: NSPoint(x: 512, y: 802), controlPoint1: NSPoint(x: 286, y: 707), controlPoint2: NSPoint(x: 378, y: 802))
arch.curve(to: NSPoint(x: 738, y: 566), controlPoint1: NSPoint(x: 646, y: 802), controlPoint2: NSPoint(x: 738, y: 707))
arch.line(to: NSPoint(x: 738, y: 236)); arch.close()
arch.lineWidth = 17; arch.lineJoinStyle = .round; arch.stroke()
let leaf = NSBezierPath()
leaf.move(to: NSPoint(x: 425, y: 421))
leaf.curve(to: NSPoint(x: 621, y: 651), controlPoint1: NSPoint(x: 366, y: 554), controlPoint2: NSPoint(x: 498, y: 634))
leaf.curve(to: NSPoint(x: 425, y: 421), controlPoint1: NSPoint(x: 600, y: 510), controlPoint2: NSPoint(x: 553, y: 382))
leaf.lineWidth = 24; leaf.lineJoinStyle = .round; leaf.stroke()
let stem = NSBezierPath(); stem.move(to: NSPoint(x: 395, y: 370)); stem.curve(to: NSPoint(x: 562, y: 572), controlPoint1: NSPoint(x: 435, y: 470), controlPoint2: NSPoint(x: 496, y: 525)); stem.lineWidth = 22; stem.lineCapStyle = .round; stem.stroke()
NSGraphicsContext.restoreGraphicsState()
let destination = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("ios/App/Resources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent("AppIcon.png"))
let contents: [String: Any] = ["images": [["filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"]], "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: destination.appendingPathComponent("Contents.json"))
