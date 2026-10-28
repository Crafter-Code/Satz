import AppKit
import Foundation

let destination = CommandLine.arguments[1]
let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("satz-icon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
for (name, pixels) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)] {
    let size = CGFloat(pixels)
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let rect = NSRect(x: size * 0.06, y: size * 0.06, width: size * 0.88, height: size * 0.88)
    NSColor(calibratedRed: 0.085, green: 0.105, blue: 0.14, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect, xRadius: size * 0.21, yRadius: size * 0.21).fill()
    let ink = NSColor(calibratedRed: 0.96, green: 0.65, blue: 0.27, alpha: 1)
    let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
    ("S" as NSString).draw(in: NSRect(x: size * 0.07, y: size * 0.18, width: size * 0.72, height: size * 0.66), withAttributes: [.font: NSFont.systemFont(ofSize: size * 0.6, weight: .semibold), .foregroundColor: NSColor.white, .paragraphStyle: paragraph])
    ink.setFill()
    NSBezierPath(roundedRect: NSRect(x: size * 0.69, y: size * 0.29, width: size * 0.055, height: size * 0.43), xRadius: size * 0.02, yRadius: size * 0.02).fill()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent(name + ".png"))
}
func sizeBytes(_ size: Int) -> Data {
    var value = UInt32(size).bigEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}
var chunks = Data()
for (type, name) in [("icp4","icon_16x16"),("icp5","icon_32x32"),("icp6","icon_32x32@2x"),("ic07","icon_128x128"),("ic08","icon_256x256"),("ic09","icon_512x512"),("ic10","icon_512x512@2x")] {
    let png = try Data(contentsOf: root.appendingPathComponent(name + ".png"))
    chunks.append(Data(type.utf8)); chunks.append(sizeBytes(png.count + 8)); chunks.append(png)
}
var icns = Data("icns".utf8); icns.append(sizeBytes(chunks.count + 8)); icns.append(chunks)
try icns.write(to: URL(fileURLWithPath: destination))
try FileManager.default.removeItem(at: root)
