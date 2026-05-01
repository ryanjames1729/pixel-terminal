#!/usr/bin/swift
import AppKit
import CoreGraphics

// Draws the Pixel Terminal icon at a given size
func makeIcon(size: Int) -> Data? {
    let s = CGFloat(size)
    let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: .alphaFirst,
        bytesPerRow: 0, bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
    guard let ctx = NSGraphicsContext.current?.cgContext else { return nil }

    // ── Background: radial gradient dark navy → deep indigo ─────────────
    let bgColors = [
        CGColor(red: 0.11, green: 0.11, blue: 0.24, alpha: 1),
        CGColor(red: 0.04, green: 0.04, blue: 0.10, alpha: 1)
    ] as CFArray
    let locs: [CGFloat] = [0, 1]
    let cs = CGColorSpaceCreateDeviceRGB()
    if let grad = CGGradient(colorsSpace: cs, colors: bgColors, locations: locs) {
        ctx.drawRadialGradient(
            grad,
            startCenter: CGPoint(x: s * 0.5, y: s * 0.55), startRadius: 0,
            endCenter:   CGPoint(x: s * 0.5, y: s * 0.5),  endRadius: s * 0.72,
            options: [.drawsAfterEndLocation]
        )
    }

    // ── Subtle pixel grid overlay ────────────────────────────────────────
    let gridSpacing = s / 14
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.025))
    ctx.setLineWidth(0.5)
    var x = gridSpacing
    while x < s {
        ctx.move(to: CGPoint(x: x, y: 0))
        ctx.addLine(to: CGPoint(x: x, y: s))
        x += gridSpacing
    }
    var y = gridSpacing
    while y < s {
        ctx.move(to: CGPoint(x: 0, y: y))
        ctx.addLine(to: CGPoint(x: s, y: y))
        y += gridSpacing
    }
    ctx.strokePath()

    // ── Glow layer: draw >_ twice, blurred, for the halo effect ──────────
    let indigoGlow = CGColor(red: 0.51, green: 0.55, blue: 0.97, alpha: 0.35)
    ctx.setShadow(offset: .zero, blur: s * 0.07, color: indigoGlow)

    // ── Main text: >_ ────────────────────────────────────────────────────
    let fontSize = s * 0.36
    let fontRef = CTFontCreateWithName("SFMono-Regular" as CFString, fontSize, nil)
    let fallback = CTFontCreateWithName("Menlo-Regular" as CFString, fontSize, nil)
    let font = CTFontGetSize(fontRef) > 0 ? fontRef : fallback

    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(red: 0.62, green: 0.66, blue: 0.98, alpha: 1.0)
    ]
    let attrStr = NSAttributedString(string: ">_", attributes: attrs)
    let line = CTLineCreateWithAttributedString(attrStr)

    var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
    let textWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
    let textHeight = ascent + descent

    let tx = (s - CGFloat(textWidth)) / 2
    let ty = (s - textHeight) / 2 + descent + s * 0.02

    ctx.textPosition = CGPoint(x: tx, y: ty)
    CTLineDraw(line, ctx)

    // ── Cursor blink dot ─────────────────────────────────────────────────
    ctx.setShadow(offset: .zero, blur: s * 0.03,
                  color: CGColor(red: 0.51, green: 0.55, blue: 0.97, alpha: 0.6))
    let dotSize = s * 0.032
    let dotX = tx + CGFloat(textWidth) + s * 0.01
    let dotY = ty + descent
    ctx.setFillColor(CGColor(red: 0.62, green: 0.66, blue: 0.98, alpha: 0.9))
    ctx.fillEllipse(in: CGRect(x: dotX, y: dotY, width: dotSize, height: dotSize * 1.5))

    NSGraphicsContext.restoreGraphicsState()

    return bitmapRep.representation(using: .png, properties: [:])
}

// ── Iconset sizes ────────────────────────────────────────────────────────────
let iconsetDir = "Resources/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(size: Int, name: String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for entry in sizes {
    if let data = makeIcon(size: entry.size) {
        let path = "\(iconsetDir)/\(entry.name)"
        try? data.write(to: URL(fileURLWithPath: path))
        print("✓ \(path)  (\(entry.size)px)")
    }
}

// ── Convert to .icns with iconutil ───────────────────────────────────────────
print("\n▶ Running iconutil...")
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetDir, "-o", "Resources/AppIcon.icns"]
try? proc.run()
proc.waitUntilExit()

if proc.terminationStatus == 0 {
    print("✓ Resources/AppIcon.icns")
    print("\nDone! Re-run build.sh to bundle the icon.")
} else {
    print("✗ iconutil failed — run manually:")
    print("  iconutil -c icns \(iconsetDir) -o Resources/AppIcon.icns")
}
