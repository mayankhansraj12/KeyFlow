#!/usr/bin/env swift

import AppKit
import Foundation

private enum InstallerArtwork {
    static let scale: CGFloat = 2
    static let logicalSize = NSSize(width: 760, height: 438)
    static let pixelSize = NSSize(
        width: logicalSize.width * scale,
        height: logicalSize.height * scale
    )
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: render-dmg-background.swift <output.png>\n".utf8))
    exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let width = Int(InstallerArtwork.pixelSize.width)
let height = Int(InstallerArtwork.pixelSize.height)

guard
    let bitmapContext = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )
else {
    FileHandle.standardError.write(Data("Could not create the installer background canvas.\n".utf8))
    exit(1)
}

let context = NSGraphicsContext(cgContext: bitmapContext, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.shouldAntialias = true
context.imageInterpolation = .high
bitmapContext.scaleBy(x: InstallerArtwork.scale, y: InstallerArtwork.scale)

let canvas = NSRect(origin: .zero, size: InstallerArtwork.logicalSize)
NSGradient(
    colors: [
        NSColor(calibratedRed: 0.985, green: 0.985, blue: 0.97, alpha: 1),
        NSColor(calibratedRed: 0.965, green: 0.975, blue: 0.995, alpha: 1),
        NSColor(calibratedRed: 0.99, green: 0.98, blue: 0.97, alpha: 1),
    ]
)?.draw(in: canvas, angle: -12)

let titleStyle = NSMutableParagraphStyle()
titleStyle.alignment = .center
let title = NSAttributedString(
    string: "Install KeyFlow",
    attributes: [
        .font: NSFont.systemFont(ofSize: 31, weight: .bold),
        .foregroundColor: NSColor(calibratedWhite: 0.08, alpha: 1),
        .paragraphStyle: titleStyle,
    ]
)
title.draw(in: NSRect(x: 80, y: 363, width: 600, height: 42))

let subtitle = NSAttributedString(
    string: "Drag KeyFlow to Applications",
    attributes: [
        .font: NSFont.systemFont(ofSize: 17, weight: .regular),
        .foregroundColor: NSColor(calibratedWhite: 0.38, alpha: 1),
        .paragraphStyle: titleStyle,
    ]
)
subtitle.draw(in: NSRect(x: 80, y: 331, width: 600, height: 26))

let arrowColor = NSColor(calibratedWhite: 0.48, alpha: 1)
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 325, y: 174))
arrow.line(to: NSPoint(x: 435, y: 174))
arrowColor.setStroke()
arrow.lineWidth = 4
arrow.lineCapStyle = .round
arrow.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 416, y: 193))
arrowHead.line(to: NSPoint(x: 437, y: 174))
arrowHead.line(to: NSPoint(x: 416, y: 155))
arrowHead.lineWidth = 4
arrowHead.lineCapStyle = .round
arrowHead.lineJoinStyle = .round
arrowColor.setStroke()
arrowHead.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let image = bitmapContext.makeImage() else {
    FileHandle.standardError.write(Data("Could not finalize the installer background.\n".utf8))
    exit(1)
}

let bitmap = NSBitmapImageRep(cgImage: image)
bitmap.size = InstallerArtwork.logicalSize
guard let data = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Could not encode the installer background.\n".utf8))
    exit(1)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try data.write(to: outputURL, options: .atomic)
