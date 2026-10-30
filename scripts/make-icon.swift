// Draws Basket's app icon and logo with Core Graphics.
//
//   swift scripts/make-icon.swift preview <dir>   # contact sheet + logos for every option
//   swift scripts/make-icon.swift install <A|B|C|D>   # writes AppIcon.appiconset
//
// Artwork is drawn on a 1024pt grid using Apple's macOS icon template
// (824pt rounded square, inset 100pt) and rendered fresh at each size.

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Palette

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

let cream = rgb(0xFAF5EE)
let terracotta = rgb(0xC4633F) // Hearth's background
let ink = rgb(0x2A2623)

// MARK: - Geometry helpers (top-left origin, 1024pt canvas)

let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tileRadius: CGFloat = 185

func letterPath(_ text: String, font name: String, size: CGFloat) -> CGPath {
    let font = CTFontCreateWithName(name as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: text, attributes: [kCTFontAttributeName as NSAttributedString.Key: font]))
    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
        for (glyph, position) in zip(glyphs, positions) {
            // Glyph outlines are y-up; flip them into the y-down canvas.
            var transform = CGAffineTransform(translationX: position.x, y: 0).scaledBy(x: 1, y: -1)
            if let glyphPath = CTFontCreatePathForGlyph(font, glyph, &transform) {
                path.addPath(glyphPath)
            }
        }
    }
    return path
}

func centered(_ path: CGPath, at center: CGPoint) -> CGPath {
    let box = path.boundingBoxOfPath
    var move = CGAffineTransform(translationX: center.x - box.midX, y: center.y - box.midY)
    return path.copy(using: &move)!
}

func roundedTrapezoid(top: CGFloat, bottom: CGFloat, topWidth: CGFloat, bottomWidth: CGFloat,
                      radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let tl = CGPoint(x: 512 - topWidth / 2, y: top), tr = CGPoint(x: 512 + topWidth / 2, y: top)
    let br = CGPoint(x: 512 + bottomWidth / 2, y: bottom), bl = CGPoint(x: 512 - bottomWidth / 2, y: bottom)
    path.move(to: CGPoint(x: 512, y: top))
    path.addArc(tangent1End: tr, tangent2End: br, radius: radius)
    path.addArc(tangent1End: br, tangent2End: bl, radius: radius)
    path.addArc(tangent1End: bl, tangent2End: tl, radius: radius)
    path.addArc(tangent1End: tl, tangent2End: tr, radius: radius)
    path.closeSubpath()
    return path
}

/// Basket bowl: a rim with a tapered, two-band body below it. Returns paths in the y-down canvas.
func basketBowl(rimTop: CGFloat, color: CGColor, gap: CGColor, in ctx: CGContext) {
    let rim = CGPath(roundedRect: CGRect(x: 512 - 296, y: rimTop, width: 592, height: 76),
                     cornerWidth: 38, cornerHeight: 38, transform: nil)
    let body = roundedTrapezoid(top: rimTop + 100, bottom: rimTop + 300,
                                topWidth: 520, bottomWidth: 392, radius: 36)
    ctx.setFillColor(color)
    ctx.addPath(rim)
    ctx.addPath(body)
    ctx.fillPath()
    // A single cut across the body reads as weave without muddying small sizes.
    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    ctx.setFillColor(gap)
    ctx.fill(CGRect(x: 0, y: rimTop + 188, width: 1024, height: 24))
    ctx.restoreGState()
}

// MARK: - Options

struct Option {
    let id: String
    let name: String
    let background: CGColor
    let draw: (CGContext) -> Void
}

let bLetter = centered(letterPath("B", font: "Superclarendon-BlackItalic", size: 600),
                       at: CGPoint(x: 512, y: 512))

let options: [Option] = [
    Option(id: "A", name: "Sibling", background: rgb(0x2F5D5A)) { ctx in
        ctx.setFillColor(cream)
        ctx.addPath(bLetter)
        ctx.fillPath()
    },
    Option(id: "B", name: "Woven", background: rgb(0xB7793A)) { ctx in
        // Basket weave: alternating cells of horizontal and vertical reeds.
        ctx.setFillColor(rgb(0x9F6630))
        let cell: CGFloat = 103
        for row in 0..<8 {
            for col in 0..<8 {
                let origin = CGPoint(x: 100 + CGFloat(col) * cell, y: 100 + CGFloat(row) * cell)
                for i in 0..<3 {
                    let offset = CGFloat(i) * cell / 3 + 13
                    if (row + col).isMultiple(of: 2) {
                        ctx.fill(CGRect(x: origin.x + 6, y: origin.y + offset, width: cell - 12, height: 8))
                    } else {
                        ctx.fill(CGRect(x: origin.x + offset, y: origin.y + 6, width: 8, height: cell - 12))
                    }
                }
            }
        }
        var drop = CGAffineTransform(translationX: 14, y: 18)
        ctx.setFillColor(rgb(0x6E421D))
        ctx.addPath(bLetter.copy(using: &drop)!)
        ctx.fillPath()
        ctx.setFillColor(cream)
        ctx.addPath(bLetter)
        ctx.fillPath()
    },
    Option(id: "C", name: "Basket", background: rgb(0x263248)) { ctx in
        let background = rgb(0x263248)
        ctx.setStrokeColor(cream)
        ctx.setLineWidth(58)
        ctx.setLineCap(.round)
        ctx.addArc(center: CGPoint(x: 512, y: 478), radius: 196,
                   startAngle: .pi, endAngle: 0, clockwise: false)
        ctx.strokePath()
        basketBowl(rimTop: 452, color: cream, gap: background, in: ctx)
    },
    Option(id: "D", name: "Basket of chats", background: rgb(0x34463A)) { ctx in
        let background = rgb(0x34463A)
        func bubble(_ center: CGPoint, _ size: CGSize, angle: CGFloat, _ color: CGColor, dots: Bool = false) {
            ctx.saveGState()
            ctx.translateBy(x: center.x, y: center.y)
            ctx.rotate(by: angle)
            let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
            ctx.setFillColor(color)
            ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 70, cornerHeight: 70, transform: nil))
            ctx.fillPath()
            if dots {
                ctx.setFillColor(background)
                for dx in [-62, 0, 62] as [CGFloat] {
                    ctx.fillEllipse(in: CGRect(x: dx - 22, y: -42, width: 44, height: 44))
                }
            }
            ctx.restoreGState()
        }
        bubble(CGPoint(x: 360, y: 470), CGSize(width: 250, height: 210), angle: -0.2, terracotta)
        bubble(CGPoint(x: 664, y: 462), CGSize(width: 250, height: 210), angle: 0.2, rgb(0xE0A93B))
        bubble(CGPoint(x: 512, y: 380), CGSize(width: 300, height: 240), angle: 0, rgb(0x8DB3D6), dots: true)
        basketBowl(rimTop: 520, color: cream, gap: background, in: ctx)
    },
]

// MARK: - Rendering

func makeContext(width: Int, height: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(height))
    ctx.scaleBy(x: 1, y: -1)
    return ctx
}

/// Draws the icon into the 1024pt square at the context's current transform.
func drawIcon(_ option: Option, in ctx: CGContext, pixelScale: CGFloat) {
    let shape = CGPath(roundedRect: tile, cornerWidth: tileRadius, cornerHeight: tileRadius, transform: nil)
    ctx.saveGState()
    // Apple's template shadow; shadow offsets are in device space, so scale them.
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * pixelScale), blur: 20 * pixelScale,
                  color: rgb(0x000000, 0.3))
    ctx.setFillColor(option.background)
    ctx.addPath(shape)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    option.draw(ctx)
    ctx.restoreGState()
}

func renderIcon(_ option: Option, pixels: Int) -> CGImage {
    let ctx = makeContext(width: pixels, height: pixels)
    let scale = CGFloat(pixels) / 1024
    ctx.scaleBy(x: scale, y: scale)
    drawIcon(option, in: ctx, pixelScale: scale)
    return ctx.makeImage()!
}

/// Icon plus "Basket" wordmark, for the README, website or About window.
func renderLogo(_ option: Option, textColor: CGColor) -> CGImage {
    let ctx = makeContext(width: 1400, height: 400)
    ctx.saveGState()
    ctx.translateBy(x: -20, y: -20)
    ctx.scaleBy(x: 440 / 1024, y: 440 / 1024)
    drawIcon(option, in: ctx, pixelScale: 440 / 1024)
    ctx.restoreGState()
    let word = letterPath("Basket", font: "Superclarendon-BlackItalic", size: 210)
    let box = word.boundingBoxOfPath
    var move = CGAffineTransform(translationX: 420 - box.minX, y: 200 - box.midY)
    ctx.setFillColor(textColor)
    ctx.addPath(word.copy(using: &move)!)
    ctx.fillPath()
    return ctx.makeImage()!
}

/// Every option at Dock, Finder and menu sizes, on light and dark backgrounds.
func renderContactSheet() -> CGImage {
    let sizes = [256, 128, 64, 32, 16]
    let rowHeight = 340, labelWidth = 0, panelWidth = 640
    let ctx = makeContext(width: labelWidth + panelWidth * 2, height: rowHeight * options.count)
    for (row, option) in options.enumerated() {
        for (panel, bg) in [rgb(0xF2F0EC), rgb(0x1E1E1E)].enumerated() {
            let originX = CGFloat(labelWidth + panel * panelWidth)
            let originY = CGFloat(row * rowHeight)
            ctx.setFillColor(bg)
            ctx.fill(CGRect(x: originX, y: originY, width: CGFloat(panelWidth), height: CGFloat(rowHeight)))
            var x = originX + 22
            for size in sizes {
                let s = CGFloat(size)
                ctx.saveGState()
                ctx.translateBy(x: x, y: originY + 30 + (CGFloat(rowHeight) - s) / 2)
                ctx.scaleBy(x: s / 1024, y: s / 1024)
                drawIcon(option, in: ctx, pixelScale: s / 1024)
                ctx.restoreGState()
                x += s + 24
            }
            if panel == 0 {
                let label = letterPath("\(option.id)  \(option.name)", font: "Superclarendon-Bold", size: 26)
                var move = CGAffineTransform(translationX: originX + 24 - label.boundingBoxOfPath.minX,
                                             y: originY + 34)
                ctx.setFillColor(ink)
                ctx.addPath(label.copy(using: &move)!)
                ctx.fillPath()
            }
        }
    }
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("Could not write \(url.path)") }
}

// MARK: - Commands

let args = CommandLine.arguments.dropFirst()
switch (args.first, args.dropFirst().first) {
case ("preview", let dir?):
    let out = URL(fileURLWithPath: dir)
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    writePNG(renderContactSheet(), to: out.appendingPathComponent("contact-sheet.png"))
    for option in options {
        writePNG(renderIcon(option, pixels: 1024), to: out.appendingPathComponent("icon-\(option.id).png"))
        writePNG(renderLogo(option, textColor: ink), to: out.appendingPathComponent("logo-\(option.id).png"))
        writePNG(renderLogo(option, textColor: cream), to: out.appendingPathComponent("logo-\(option.id)-dark.png"))
    }
    print("Wrote previews to \(out.path)")

case ("install", let id?):
    guard let option = options.first(where: { $0.id == id.uppercased() }) else {
        fatalError("Unknown option \(id). Choose one of \(options.map(\.id).joined(separator: ", ")).")
    }
    let script = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    let iconSet = script.deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Basket/Resources/Assets.xcassets/AppIcon.appiconset")
    var images: [[String: String]] = []
    for size in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let file = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
            writePNG(renderIcon(option, pixels: size * scale), to: iconSet.appendingPathComponent(file))
            images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(size)x\(size)", "filename": file])
        }
    }
    let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
    let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try json.write(to: iconSet.appendingPathComponent("Contents.json"))
    print("Installed option \(option.id) (\(option.name)) into \(iconSet.path)")

default:
    print("usage: swift scripts/make-icon.swift preview <dir> | install <A|B|C|D>")
    exit(1)
}
