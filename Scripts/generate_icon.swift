// Original vector artwork for Personal Guitar Coach. No fonts or external images.
// Run from the repository root: xcrun swift Scripts/generate_icon.swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let catalog = root.appendingPathComponent("Resources/Assets.xcassets")
let appIcon = catalog.appendingPathComponent("AppIcon.appiconset")
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try FileManager.default.createDirectory(at: appIcon, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
func writeJSON(_ value: Any, to url: URL) throws {
    try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: url)
}
let info: [String: Any] = ["author": "xcode", "version": 1]
try writeJSON(["info": info], to: catalog.appendingPathComponent("Contents.json"))

func draw(size: Int, to url: URL) throws {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw NSError(domain: "IconGeneration", code: 1)
    }
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    context.setShouldAntialias(true)
    func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
        CGColor(colorSpace: space, components: [r, g, b, a])!
    }
    let tile = CGPath(roundedRect: CGRect(x: 72, y: 72, width: 880, height: 880), cornerWidth: 196, cornerHeight: 196, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0, 0, 0, 0.3))
    context.addPath(tile); context.setFillColor(color(0.06, 0.1, 0.16)); context.fillPath()
    context.restoreGState()
    context.saveGState(); context.addPath(tile); context.clip()
    let gradient = CGGradient(colorsSpace: space, colors: [color(0.045, 0.085, 0.14), color(0.12, 0.24, 0.30)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 200, y: 70), end: CGPoint(x: 824, y: 952), options: [])
    context.restoreGState()
    let neck = CGPath(roundedRect: CGRect(x: 294, y: 190, width: 436, height: 640), cornerWidth: 42, cornerHeight: 42, transform: nil)
    context.addPath(neck); context.setFillColor(color(0.18, 0.30, 0.34)); context.fillPath()
    context.setStrokeColor(color(0.79, 0.88, 0.85, 0.45)); context.setLineWidth(9)
    for y in [308, 428, 548, 668, 788] {
        context.move(to: CGPoint(x: 304, y: y)); context.addLine(to: CGPoint(x: 720, y: y)); context.strokePath()
    }
    let accent = color(1, 0.67, 0.27)
    context.setLineCap(.round)
    for string in 0..<6 {
        let x = 328 + string * 74
        context.setStrokeColor(string == 3 ? accent : color(0.9, 0.95, 0.91, 0.88))
        context.setLineWidth(string == 3 ? 8 : CGFloat(7) - CGFloat(string) * 0.5)
        context.move(to: CGPoint(x: x, y: 210)); context.addLine(to: CGPoint(x: x, y: 840)); context.strokePath()
    }
    context.setFillColor(color(0.91, 0.93, 0.85))
    context.addPath(CGPath(roundedRect: CGRect(x: 294, y: 805, width: 436, height: 28), cornerWidth: 12, cornerHeight: 12, transform: nil)); context.fillPath()
    context.setFillColor(color(1, 0.67, 0.27, 0.16)); context.fillEllipse(in: CGRect(x: 470, y: 532, width: 160, height: 160))
    context.setFillColor(accent); context.fillEllipse(in: CGRect(x: 498, y: 560, width: 104, height: 104))
    context.setStrokeColor(color(1, 0.94, 0.8)); context.setLineWidth(10); context.strokeEllipse(in: CGRect(x: 498, y: 560, width: 104, height: 104))
    context.setFillColor(color(0.09, 0.18, 0.23)); context.fillEllipse(in: CGRect(x: 537, y: 599, width: 26, height: 26))
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "IconGeneration", code: 2)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "IconGeneration", code: 3) }
}
var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let filename = "icon_\(points)x\(points)" + (scale == 2 ? "@2x" : "") + ".png"
        let file = appIcon.appendingPathComponent(filename)
        try draw(size: points * scale, to: file)
        let target = iconset.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
        try FileManager.default.copyItem(at: file, to: target)
        images.append(["filename": filename, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"])
    }
}
try writeJSON(["images": images, "info": info], to: appIcon.appendingPathComponent("Contents.json"))
let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try process.run(); process.waitUntilExit()
guard process.terminationStatus == 0 else { throw NSError(domain: "IconGeneration", code: Int(process.terminationStatus)) }
print("Generated original macOS icon: ten PNG representations and AppIcon.icns")
