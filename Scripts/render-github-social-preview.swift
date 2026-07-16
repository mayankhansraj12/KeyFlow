#!/usr/bin/env swift

import AppKit
import Foundation

private enum Artwork {
    static let size = NSSize(width: 1280, height: 640)
}

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(
        Data(
            "Usage: render-github-social-preview.swift <app-icon.png> <output.png>\n"
                .utf8
        )
    )
    exit(64)
}

let iconURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard
    let icon = NSImage(contentsOf: iconURL),
    let bitmapContext = CGContext(
        data: nil,
        width: Int(Artwork.size.width),
        height: Int(Artwork.size.height),
        bitsPerComponent: 8,
        bytesPerRow: Int(Artwork.size.width) * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )
else {
    FileHandle.standardError.write(
        Data("Could not create the GitHub preview artwork.\n".utf8)
    )
    exit(1)
}

let context = NSGraphicsContext(cgContext: bitmapContext, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.shouldAntialias = true
context.imageInterpolation = .high

let canvas = NSRect(origin: .zero, size: Artwork.size)
NSGradient(
    colors: [
        NSColor(calibratedRed: 0.025, green: 0.07, blue: 0.16, alpha: 1),
        NSColor(calibratedRed: 0.03, green: 0.18, blue: 0.38, alpha: 1),
        NSColor(calibratedRed: 0.02, green: 0.08, blue: 0.20, alpha: 1),
    ]
)?.draw(in: canvas, angle: -18)

let glow = NSBezierPath(
    ovalIn: NSRect(x: 640, y: -180, width: 760, height: 760)
)
NSColor(calibratedRed: 0.05, green: 0.55, blue: 1, alpha: 0.16).setFill()
glow.fill()

let iconShadow = NSShadow()
iconShadow.shadowBlurRadius = 42
iconShadow.shadowOffset = NSSize(width: 0, height: -10)
iconShadow.shadowColor = NSColor.black.withAlphaComponent(0.42)
iconShadow.set()

icon.draw(
    in: NSRect(x: 120, y: 120, width: 400, height: 400),
    from: .zero,
    operation: .sourceOver,
    fraction: 1
)

NSShadow().set()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .left

NSAttributedString(
    string: "KeyFlow",
    attributes: [
        .font: NSFont.systemFont(ofSize: 82, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph,
    ]
).draw(in: NSRect(x: 600, y: 342, width: 570, height: 110))

NSAttributedString(
    string: "Shortcuts, gestures, and fluid window switching for macOS.",
    attributes: [
        .font: NSFont.systemFont(ofSize: 34, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.76),
        .paragraphStyle: paragraph,
    ]
).draw(in: NSRect(x: 605, y: 215, width: 560, height: 110))

let pill = NSBezierPath(
    roundedRect: NSRect(x: 605, y: 145, width: 330, height: 48),
    xRadius: 24,
    yRadius: 24
)
NSColor.white.withAlphaComponent(0.1).setFill()
pill.fill()
NSColor.white.withAlphaComponent(0.18).setStroke()
pill.lineWidth = 1
pill.stroke()

let pillParagraph = NSMutableParagraphStyle()
pillParagraph.alignment = .center
NSAttributedString(
    string: "OPEN SOURCE · NATIVE MACOS",
    attributes: [
        .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
        .foregroundColor: NSColor.white.withAlphaComponent(0.9),
        .paragraphStyle: pillParagraph,
        .kern: 0.7,
    ]
).draw(in: NSRect(x: 605, y: 158, width: 330, height: 22))

NSGraphicsContext.restoreGraphicsState()

guard let image = bitmapContext.makeImage() else {
    FileHandle.standardError.write(
        Data("Could not finalize the GitHub preview artwork.\n".utf8)
    )
    exit(1)
}

let bitmap = NSBitmapImageRep(cgImage: image)
guard let data = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(
        Data("Could not encode the GitHub preview artwork.\n".utf8)
    )
    exit(1)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try data.write(to: outputURL, options: .atomic)
