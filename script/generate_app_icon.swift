import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Native vector drawing keeps the mark editable and needs no external assets or fonts.
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let output = root.appendingPathComponent("MDJournal/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let ink = CGColor(srgbRed: 0.19, green: 0.34, blue: 0.29, alpha: 1)
let paper = CGColor(srgbRed: 0.97, green: 0.96, blue: 0.92, alpha: 1)
let pale = CGColor(srgbRed: 0.77, green: 0.83, blue: 0.72, alpha: 1)

for size in [16, 32, 64, 128, 256, 512, 1024] {
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    context.setFillColor(paper)
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 24,
                      color: CGColor(srgbRed: 0.08, green: 0.18, blue: 0.14, alpha: 0.16))
    context.setFillColor(ink)
    context.addPath(CGPath(roundedRect: CGRect(x: 220, y: 158, width: 584, height: 708),
                          cornerWidth: 68, cornerHeight: 68, transform: nil))
    context.fillPath()
    context.setShadow(offset: .zero, blur: 0, color: nil)
    context.setStrokeColor(pale)
    context.setLineWidth(8)
    context.move(to: CGPoint(x: 316, y: 202)); context.addLine(to: CGPoint(x: 316, y: 824))
    context.strokePath()
    context.setLineCap(.round)
    context.setStrokeColor(paper)
    context.setLineWidth(18)
    let lines: [(CGFloat, CGFloat)] = [(630, 698), (540, 654), (450, 698)]
    for (y, end) in lines {
        context.move(to: CGPoint(x: 390, y: y)); context.addLine(to: CGPoint(x: end, y: y))
        context.strokePath()
    }
    let leaf = CGMutablePath()
    leaf.move(to: CGPoint(x: 600, y: 270))
    leaf.addCurve(to: CGPoint(x: 722, y: 386), control1: CGPoint(x: 596, y: 360), control2: CGPoint(x: 648, y: 398))
    leaf.addCurve(to: CGPoint(x: 600, y: 270), control1: CGPoint(x: 728, y: 300), control2: CGPoint(x: 662, y: 266))
    context.setFillColor(pale); context.addPath(leaf); context.fillPath()
    context.setStrokeColor(ink); context.setLineWidth(8)
    context.move(to: CGPoint(x: 611, y: 282)); context.addLine(to: CGPoint(x: 686, y: 358)); context.strokePath()
    let image = context.makeImage()!
    let url = output.appendingPathComponent("Icon-\(size).png")
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Unable to write icon") }
}

var images: [[String: String]] = [["filename": "Icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"]]
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        images.append(["filename": "Icon-\(size * scale).png", "idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x"])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try data.write(to: output.appendingPathComponent("Contents.json"), options: .atomic)
print("Generated iOS and Mac AppIcon assets from native vector drawing.")
