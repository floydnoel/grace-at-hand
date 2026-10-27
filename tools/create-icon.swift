import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Original vector geometry, rendered directly into an opaque, supported RGB context.
let size = 1024
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
struct DesignTokens: Decodable { let colors: [String: [String: String]] }
let colors = try JSONDecoder().decode(DesignTokens.self, from: Data(contentsOf: root.appendingPathComponent("shared/design-tokens/tokens.json"))).colors
func color(_ name: String) -> CGColor {
    guard let value = colors[name]?["light"], let hex = UInt32(value, radix: 16) else { fatalError("Missing icon color token: \(name)") }
    return CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                   green: CGFloat((hex >> 8) & 255) / 255,
                   blue: CGFloat(hex & 255) / 255, alpha: 1)
}
guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                              bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fatalError("Could not create app-icon context") }
context.setFillColor(color("ink"))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
context.setStrokeColor(color("canvas"))
context.setLineJoin(.round)
context.setLineWidth(17)
context.move(to: CGPoint(x: 286, y: 236)); context.addLine(to: CGPoint(x: 286, y: 566))
context.addCurve(to: CGPoint(x: 512, y: 802), control1: CGPoint(x: 286, y: 707), control2: CGPoint(x: 378, y: 802))
context.addCurve(to: CGPoint(x: 738, y: 566), control1: CGPoint(x: 646, y: 802), control2: CGPoint(x: 738, y: 707))
context.addLine(to: CGPoint(x: 738, y: 236)); context.closePath(); context.strokePath()
context.setLineWidth(24)
context.move(to: CGPoint(x: 425, y: 421))
context.addCurve(to: CGPoint(x: 621, y: 651), control1: CGPoint(x: 366, y: 554), control2: CGPoint(x: 498, y: 634))
context.addCurve(to: CGPoint(x: 425, y: 421), control1: CGPoint(x: 600, y: 510), control2: CGPoint(x: 553, y: 382))
context.strokePath()
context.setLineWidth(22); context.setLineCap(.round)
context.move(to: CGPoint(x: 395, y: 370))
context.addCurve(to: CGPoint(x: 562, y: 572), control1: CGPoint(x: 435, y: 470), control2: CGPoint(x: 496, y: 525))
context.strokePath()

let directory = root.appendingPathComponent("ios/App/Resources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(directory.appendingPathComponent("AppIcon.png") as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError("Could not export app icon") }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not save app icon") }
let contents: [String: Any] = ["images": [["filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"]], "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("Contents.json"))
