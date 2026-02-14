#!/usr/bin/env swift
/// Generates a multi-resolution .icns app icon for FnKeyboard.
/// Draws a rounded-rect keyboard key with "Fn" text on a gradient background.

import AppKit

/// Render the icon at a given pixel size.
func renderIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // ── Background: rounded rect with gradient ──
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let cornerRadius = s * 0.22
    let bgPath = CGPath(roundedRect: bgRect.insetBy(dx: s * 0.04, dy: s * 0.04),
                        cornerWidth: cornerRadius, cornerHeight: cornerRadius,
                        transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()

    // Gradient: dark charcoal to slightly lighter
    let colors = [
        CGColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0),
        CGColor(red: 0.25, green: 0.25, blue: 0.30, alpha: 1.0),
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: s / 2, y: s),
                           end: CGPoint(x: s / 2, y: 0),
                           options: [])
    ctx.resetClip()

    // ── Subtle outer glow / shadow ──
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01),
                  blur: s * 0.04,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.4))
    ctx.addPath(bgPath)
    ctx.setFillColor(CGColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0))
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0)

    // ── Inner keycap shape ──
    let keyInset = s * 0.18
    let keyRect = bgRect.insetBy(dx: keyInset, dy: keyInset)
    let keyCorner = s * 0.12
    let keyPath = CGPath(roundedRect: keyRect,
                         cornerWidth: keyCorner, cornerHeight: keyCorner,
                         transform: nil)

    // Key fill: slightly lighter surface
    ctx.addPath(keyPath)
    let keyColors = [
        CGColor(red: 0.28, green: 0.28, blue: 0.33, alpha: 1.0),
        CGColor(red: 0.22, green: 0.22, blue: 0.26, alpha: 1.0),
    ] as CFArray
    let keyGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                             colors: keyColors, locations: [0, 1])!
    ctx.saveGState()
    ctx.addPath(keyPath)
    ctx.clip()
    ctx.drawLinearGradient(keyGrad,
                           start: CGPoint(x: s / 2, y: keyRect.maxY),
                           end: CGPoint(x: s / 2, y: keyRect.minY),
                           options: [])
    ctx.restoreGState()

    // Key border
    ctx.addPath(keyPath)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.12))
    ctx.setLineWidth(s * 0.01)
    ctx.strokePath()

    // ── "Fn" text ──
    let fontSize = s * 0.32
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let text = "Fn" as NSString
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(red: 0.65, green: 0.78, blue: 1.0, alpha: 1.0),
    ]
    let textSize = text.size(withAttributes: attrs)
    let textOrigin = CGPoint(
        x: (s - textSize.width) / 2,
        y: (s - textSize.height) / 2 - s * 0.01
    )
    text.draw(at: textOrigin, withAttributes: attrs)

    // ── Small keyboard dots row at bottom ──
    let dotY = keyRect.minY + s * 0.08
    let dotRadius = s * 0.018
    let dotCount = 6
    let totalWidth = CGFloat(dotCount - 1) * s * 0.06
    let startX = (s - totalWidth) / 2
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.25))
    for i in 0..<dotCount {
        let cx = startX + CGFloat(i) * s * 0.06
        ctx.fillEllipse(in: CGRect(x: cx - dotRadius, y: dotY - dotRadius,
                                   width: dotRadius * 2, height: dotRadius * 2))
    }

    image.unlockFocus()
    return image
}

// ── Build the .icns ──
// iconutil expects these exact filenames in the .iconset:
//   icon_16x16.png, icon_16x16@2x.png, icon_32x32.png, icon_32x32@2x.png,
//   icon_128x128.png, icon_128x128@2x.png, icon_256x256.png, icon_256x256@2x.png,
//   icon_512x512.png, icon_512x512@2x.png
let sizeSpecs: [(point: Int, pixel: Int, suffix: String)] = [
    (16,   16,  "icon_16x16.png"),
    (16,   32,  "icon_16x16@2x.png"),
    (32,   32,  "icon_32x32.png"),
    (32,   64,  "icon_32x32@2x.png"),
    (128, 128,  "icon_128x128.png"),
    (128, 256,  "icon_128x128@2x.png"),
    (256, 256,  "icon_256x256.png"),
    (256, 512,  "icon_256x256@2x.png"),
    (512, 512,  "icon_512x512.png"),
    (512, 1024, "icon_512x512@2x.png"),
]
let iconDir = "/tmp/FnKeyboard.iconset"

let fm = FileManager.default
try? fm.removeItem(atPath: iconDir)
try! fm.createDirectory(atPath: iconDir, withIntermediateDirectories: true)

for spec in sizeSpecs {
    let img = renderIcon(size: spec.pixel)
    // Set the image size to point size so DPI is correct (72 for 1x, 144 for 2x)
    img.size = NSSize(width: spec.point, height: spec.point)
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try! png.write(to: URL(fileURLWithPath: "\(iconDir)/\(spec.suffix)"))
}

// Convert iconset → icns
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns"
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconDir, "-o", outputPath]
try! proc.run()
proc.waitUntilExit()

if proc.terminationStatus == 0 {
    print("✅  Icon created → \(outputPath)")
} else {
    print("❌  iconutil failed with status \(proc.terminationStatus)")
}
