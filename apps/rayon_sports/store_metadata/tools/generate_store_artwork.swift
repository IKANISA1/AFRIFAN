#!/usr/bin/env swift

import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let fileManager = FileManager.default
private let repositoryRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath)

private func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
    NSColor(deviceRed: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
}

private let navy = color(5, 11, 42)
private let royal = color(14, 58, 153)
private let blue = color(25, 96, 210)
private let sky = color(74, 168, 255)
private let gold = color(228, 188, 62)
private let white = color(248, 250, 255)

private func drawCentered(
    _ text: String,
    in rect: NSRect,
    font: NSFont,
    color: NSColor,
    tracking: CGFloat = 0
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byClipping
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
        .kern: tracking,
    ]
    let measured = (text as NSString).size(withAttributes: attributes)
    let target = NSRect(
        x: rect.minX,
        y: rect.midY - measured.height / 2,
        width: rect.width,
        height: measured.height
    )
    (text as NSString).draw(in: target, withAttributes: attributes)
}

private func drawLeft(
    _ text: String,
    at point: NSPoint,
    font: NSFont,
    color: NSColor,
    tracking: CGFloat = 0
) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .kern: tracking,
    ]
    (text as NSString).draw(at: point, withAttributes: attributes)
}

private func drawOrbit(in rect: NSRect, lineWidth: CGFloat, opacity: CGFloat = 1) {
    let orbit = NSBezierPath(ovalIn: rect)
    orbit.lineWidth = lineWidth
    sky.withAlphaComponent(opacity).setStroke()
    orbit.stroke()

    let markerSize = max(10, lineWidth * 2.2)
    let marker = NSBezierPath(
        ovalIn: NSRect(
            x: rect.maxX - markerSize * 1.3,
            y: rect.midY + rect.height * 0.18,
            width: markerSize,
            height: markerSize
        )
    )
    gold.withAlphaComponent(opacity).setFill()
    marker.fill()
}

private func writePNG(
    width: Int,
    height: Int,
    hasAlpha: Bool,
    destination: URL,
    draw: () -> Void
) throws {
    let bytesPerRow = width * 4
    let byteCount = bytesPerRow * height
    let pixels = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: 64)
    pixels.initializeMemory(as: UInt8.self, repeating: 0, count: byteCount)
    defer { pixels.deallocate() }

    let alphaInfo: CGImageAlphaInfo = hasAlpha ? .premultipliedLast : .noneSkipLast
    let bitmapInfo = CGBitmapInfo(rawValue:
        alphaInfo.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    )
    guard let context = CGContext(
        data: pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo.rawValue
    ) else {
        throw NSError(domain: "StoreArtwork", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Unable to create \(width)x\(height) bitmap",
        ])
    }

    let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    context.interpolationQuality = .high
    context.setShouldAntialias(true)
    draw()
    context.flush()
    NSGraphicsContext.restoreGraphicsState()

    guard let image = context.makeImage() else {
        throw NSError(domain: "StoreArtwork", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Unable to create image for \(destination.path)",
        ])
    }

    try fileManager.createDirectory(
        at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard let imageDestination = CGImageDestinationCreateWithURL(
        destination as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw NSError(domain: "StoreArtwork", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "Unable to open \(destination.path) for encoding",
        ])
    }
    CGImageDestinationAddImage(imageDestination, image, nil)
    guard CGImageDestinationFinalize(imageDestination) else {
        throw NSError(domain: "StoreArtwork", code: 4, userInfo: [
            NSLocalizedDescriptionKey: "Unable to encode \(destination.path)",
        ])
    }
}

private func drawBackground(width: CGFloat, height: CGFloat) {
    let bounds = NSRect(x: 0, y: 0, width: width, height: height)
    NSGradient(colors: [navy, royal, blue])!.draw(in: bounds, angle: 18)

    let glow = NSGradient(
        starting: sky.withAlphaComponent(0.23),
        ending: sky.withAlphaComponent(0)
    )!
    glow.draw(
        in: NSBezierPath(
            ovalIn: NSRect(
                x: width * 0.56,
                y: -height * 0.45,
                width: width * 0.7,
                height: height * 1.4
            )
        ),
        relativeCenterPosition: .zero
    )
}

private let mobileIcon = repositoryRoot
    .appendingPathComponent("apps/rayon_sports/android/fastlane/metadata/android/en-US/images/icon.png")
private let mobileFeatureGraphic = repositoryRoot
    .appendingPathComponent("apps/rayon_sports/android/fastlane/metadata/android/en-US/images/featureGraphic.png")
private let tvIcon = repositoryRoot
    .appendingPathComponent("apps/rayon_sports_tv/android/fastlane/metadata/android/en-US/images/icon.png")
private let tvBanner = repositoryRoot
    .appendingPathComponent("apps/rayon_sports_tv/android/fastlane/metadata/android/en-US/images/tvBanner.png")

try writePNG(width: 512, height: 512, hasAlpha: true, destination: mobileIcon) {
    drawBackground(width: 512, height: 512)
    drawOrbit(in: NSRect(x: 72, y: 72, width: 368, height: 368), lineWidth: 9)
    drawCentered(
        "G",
        in: NSRect(x: 96, y: 91, width: 320, height: 320),
        font: .systemFont(ofSize: 252, weight: .black),
        color: white
    )
}

try writePNG(width: 1024, height: 500, hasAlpha: false, destination: mobileFeatureGraphic) {
    drawBackground(width: 1024, height: 500)
    drawOrbit(in: NSRect(x: 82, y: 69, width: 362, height: 362), lineWidth: 8)
    drawCentered(
        "G",
        in: NSRect(x: 112, y: 89, width: 302, height: 302),
        font: .systemFont(ofSize: 236, weight: .black),
        color: white
    )
    drawLeft(
        "GIKUNDIRO",
        at: NSPoint(x: 505, y: 252),
        font: .systemFont(ofSize: 68, weight: .black),
        color: white,
        tracking: 2.2
    )
    drawLeft(
        "MATCHDAY  •  CLUB  •  COMMUNITY",
        at: NSPoint(x: 508, y: 188),
        font: .systemFont(ofSize: 24, weight: .semibold),
        color: white.withAlphaComponent(0.82),
        tracking: 1.3
    )
    let accent = NSBezierPath(roundedRect: NSRect(x: 508, y: 159, width: 164, height: 7), xRadius: 3.5, yRadius: 3.5)
    gold.setFill()
    accent.fill()
}

try writePNG(width: 512, height: 512, hasAlpha: true, destination: tvIcon) {
    drawBackground(width: 512, height: 512)
    drawOrbit(in: NSRect(x: 69, y: 69, width: 374, height: 374), lineWidth: 9)
    drawCentered(
        "G",
        in: NSRect(x: 85, y: 113, width: 342, height: 300),
        font: .systemFont(ofSize: 230, weight: .black),
        color: white
    )
    let tvPill = NSBezierPath(roundedRect: NSRect(x: 317, y: 101, width: 106, height: 66), xRadius: 25, yRadius: 25)
    gold.setFill()
    tvPill.fill()
    drawCentered(
        "TV",
        in: NSRect(x: 317, y: 101, width: 106, height: 66),
        font: .systemFont(ofSize: 31, weight: .black),
        color: navy,
        tracking: 1
    )
}

try writePNG(width: 1280, height: 720, hasAlpha: false, destination: tvBanner) {
    drawBackground(width: 1280, height: 720)
    drawOrbit(in: NSRect(x: 110, y: 110, width: 500, height: 500), lineWidth: 11)
    drawCentered(
        "G",
        in: NSRect(x: 151, y: 148, width: 418, height: 418),
        font: .systemFont(ofSize: 324, weight: .black),
        color: white
    )
    drawLeft(
        "GIKUNDIRO",
        at: NSPoint(x: 678, y: 387),
        font: .systemFont(ofSize: 82, weight: .black),
        color: white,
        tracking: 2.5
    )
    drawLeft(
        "TV",
        at: NSPoint(x: 678, y: 275),
        font: .systemFont(ofSize: 112, weight: .black),
        color: gold,
        tracking: 5
    )
    drawLeft(
        "FOOTBALL ON THE BIG SCREEN",
        at: NSPoint(x: 684, y: 229),
        font: .systemFont(ofSize: 26, weight: .semibold),
        color: white.withAlphaComponent(0.82),
        tracking: 1.6
    )
}

for output in [mobileIcon, mobileFeatureGraphic, tvIcon, tvBanner] {
    print(output.path)
}
