#!/usr/bin/env swift
import AppKit
import Foundation

/// Same plate / glyph as MacBar's BrandMark. Fills a square canvas so macOS
/// can apply the Big Sur squircle. White plate, label-gray `cpu` — same
/// grammar as cmux (light tile + mark) and the dashboard header.
enum AppIcon {
    static let plate = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
    static let glyph = "cpu"
    /// Close to macOS labelColor on a light popover (~#3A3A3C).
    static let ink = NSColor(srgbRed: 58 / 255, green: 58 / 255, blue: 60 / 255, alpha: 1)
    /// Fraction of the canvas used as SF Symbol point size.
    static let glyphScale: CGFloat = 0.52
}

let dest = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.icns")
let work = FileManager.default.temporaryDirectory
    .appendingPathComponent("HerdrBar-\(ProcessInfo.processInfo.processIdentifier).iconset")

try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

/// iconutil slots: (filename point size, scale).
let slots: [(Int, Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("no bitmap context")
    }
    ctx.imageInterpolation = .high
    ctx.shouldAntialias = true
    NSGraphicsContext.current = ctx

    let rect = NSRect(origin: .zero, size: NSSize(width: pixels, height: pixels))
    AppIcon.plate.setFill()
    rect.fill()

    let config = NSImage.SymbolConfiguration(pointSize: CGFloat(pixels) * AppIcon.glyphScale, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [AppIcon.ink]))
    guard let symbol = NSImage(systemSymbolName: AppIcon.glyph, accessibilityDescription: nil)?
        .withSymbolConfiguration(config)
    else {
        fatalError("SF Symbol \(AppIcon.glyph) is missing")
    }
    let size = symbol.size
    let draw = NSRect(
        x: (CGFloat(pixels) - size.width) / 2,
        y: (CGFloat(pixels) - size.height) / 2,
        width: size.width,
        height: size.height
    )
    symbol.draw(
        in: draw,
        from: .zero,
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("png encode failed")
    }
    return data
}

for (point, scale) in slots {
    let name = scale == 1 ? "icon_\(point)x\(point).png" : "icon_\(point)x\(point)@\(scale)x.png"
    try png(pixels: point * scale).write(to: work.appendingPathComponent(name))
}

try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", "-o", dest.path, work.path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: work)
if iconutil.terminationStatus != 0 {
    FileHandle.standardError.write(Data("iconutil failed (\(iconutil.terminationStatus))\n".utf8))
    exit(iconutil.terminationStatus)
}

print("Wrote \(dest.path)")
