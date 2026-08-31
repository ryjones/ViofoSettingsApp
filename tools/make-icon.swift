// The app icon, authored the way macOS 26/27 wants icons authored: as a stack
// of full-bleed vector layers rather than a baked bitmap.
//
//   swift tools/make-icon.swift --png <out.png> <size> [--dark|--tinted]
//   swift tools/make-icon.swift --svg <dir>
//
// Each shape is defined once, as geometry, and emitted both as an SVG path and
// as a CGPath. The SVGs are the real source: hand them to Icon Composer to
// build a .icon bundle when Xcode 26+ is available. The PNG/.icns path is the
// fallback for the plain bundle this project ships, which is why it bakes in
// the squircle mask -- .icns has no system masking, so the shape has to be
// drawn. Layers stay full-bleed and unmasked in the SVGs, as the layered format
// expects.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let A = CommandLine.arguments
let S = 1024.0                                  // authoring canvas; everything is a ratio of it

// MARK: - Geometry, defined once

/// The V. A stroked polyline, so the join stays a real corner at every size.
let vHalf = 0.175, vTop = 0.315, vBottom = 0.695     // as fractions, y down
let vPoints = [(0.5 - vHalf, vTop), (0.5, vBottom), (0.5 + vHalf, vTop)]
let vStroke = 0.105

/// A four-pointed sparkle: a diamond with concave sides, as four quad curves.
struct Sparkle { let x, y, r, alpha: Double }
let sparkles = [Sparkle(x: 0.735, y: 0.265, r: 0.088, alpha: 1.00),
                Sparkle(x: 0.268, y: 0.360, r: 0.050, alpha: 0.92),
                Sparkle(x: 0.660, y: 0.710, r: 0.038, alpha: 0.80)]

func sparkleD(_ s: Sparkle, _ u: Double) -> String {
    let cx = s.x * u, cy = s.y * u, r = s.r * u, k = s.r * u * 0.16
    return "M \(cx) \(cy - r) Q \(cx + k) \(cy - k) \(cx + r) \(cy) "
         + "Q \(cx + k) \(cy + k) \(cx) \(cy + r) "
         + "Q \(cx - k) \(cy + k) \(cx - r) \(cy) "
         + "Q \(cx - k) \(cy - k) \(cx) \(cy - r) Z"
}

func vD(_ u: Double) -> String {
    "M \(vPoints[0].0 * u) \(vPoints[0].1 * u) "
    + "L \(vPoints[1].0 * u) \(vPoints[1].1 * u) "
    + "L \(vPoints[2].0 * u) \(vPoints[2].1 * u)"
}

// MARK: - Palettes
//
// One per appearance, because the layered format carries light, dark and
// tinted variants rather than a single flattened image.

struct Palette { let top, mid, bottom, glyph, spark: [Double] }
let light  = Palette(top: [0.20, 0.24, 0.52], mid: [0.40, 0.19, 0.62], bottom: [0.10, 0.12, 0.30],
                     glyph: [1, 1, 1], spark: [1, 0.93, 0.62])
let dark   = Palette(top: [0.10, 0.12, 0.28], mid: [0.24, 0.11, 0.38], bottom: [0.04, 0.05, 0.14],
                     glyph: [0.97, 0.97, 1], spark: [1, 0.90, 0.55])
let tinted = Palette(top: [0.30, 0.30, 0.32], mid: [0.42, 0.42, 0.45], bottom: [0.16, 0.16, 0.18],
                     glyph: [1, 1, 1], spark: [0.90, 0.90, 0.92])

func hex(_ c: [Double]) -> String {
    String(format: "#%02X%02X%02X", Int(c[0] * 255), Int(c[1] * 255), Int(c[2] * 255))
}

// MARK: - SVG layers

func writeSVGs(_ dir: String) throws {
    let fm = FileManager.default
    try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let u = S
    func doc(_ body: String) -> String {
        """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(Int(u))" height="\(Int(u))" \
        viewBox="0 0 \(Int(u)) \(Int(u))">
        \(body)
        </svg>
        """
    }
    // Full bleed. The system applies the icon shape; the layer must not.
    for (name, p) in [("light", light), ("dark", dark), ("tinted", tinted)] {
        let bg = doc("""
          <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stop-color="\(hex(p.top))"/>
            <stop offset="0.55" stop-color="\(hex(p.mid))"/>
            <stop offset="1" stop-color="\(hex(p.bottom))"/>
          </linearGradient></defs>
          <rect width="\(Int(u))" height="\(Int(u))" fill="url(#g)"/>
        """)
        try bg.write(toFile: "\(dir)/background-\(name).svg", atomically: true, encoding: .utf8)
    }
    let glyph = doc("""
      <path d="\(vD(u))" fill="none" stroke="\(hex(light.glyph))" stroke-width="\(vStroke * u)" \
    stroke-linecap="round" stroke-linejoin="round"/>
    """)
    try glyph.write(toFile: "\(dir)/glyph.svg", atomically: true, encoding: .utf8)

    let spark = doc(sparkles.map {
        "  <path d=\"\(sparkleD($0, u))\" fill=\"\(hex(light.spark))\" fill-opacity=\"\($0.alpha)\"/>"
    }.joined(separator: "\n"))
    try spark.write(toFile: "\(dir)/sparkles.svg", atomically: true, encoding: .utf8)
}

// MARK: - Raster

func writePNG(_ out: String, _ size: Double, _ p: Palette) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
                              bytesPerRow: 0, space: space,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high
    // SVG is y-down, CoreGraphics is y-up. Flip once so one set of numbers serves both.
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)

    func color(_ c: [Double], _ a: Double = 1) -> CGColor {
        CGColor(colorSpace: space, components: [c[0], c[1], c[2], a])!
    }

    // .icns carries no system mask, so the icon shape is drawn here. The macOS
    // squircle is close to a 22.5% continuous corner; a plain rounded rect is a
    // fair approximation at these sizes.
    let inset = size * 0.085
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225,
                       cornerHeight: rect.height * 0.225, transform: nil))
    ctx.clip()

    let grad = CGGradient(colorsSpace: space,
                          colors: [color(p.top), color(p.mid), color(p.bottom)] as CFArray,
                          locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: size, y: size), options: [])

    // Foreground layers are drawn at the same ratios, scaled into the plate so
    // nothing lands under the mask's corners.
    ctx.translateBy(x: rect.minX, y: rect.minY)
    let u = rect.width

    let v = CGMutablePath()
    v.move(to: CGPoint(x: vPoints[0].0 * u, y: vPoints[0].1 * u))
    v.addLine(to: CGPoint(x: vPoints[1].0 * u, y: vPoints[1].1 * u))
    v.addLine(to: CGPoint(x: vPoints[2].0 * u, y: vPoints[2].1 * u))
    ctx.setStrokeColor(color(p.glyph, 0.97))
    ctx.setLineWidth(vStroke * u)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(v)
    ctx.strokePath()

    for s in sparkles {
        let cx = s.x * u, cy = s.y * u, r = s.r * u, k = s.r * u * 0.16
        let path = CGMutablePath()
        path.move(to: CGPoint(x: cx, y: cy - r))
        path.addQuadCurve(to: CGPoint(x: cx + r, y: cy), control: CGPoint(x: cx + k, y: cy - k))
        path.addQuadCurve(to: CGPoint(x: cx, y: cy + r), control: CGPoint(x: cx + k, y: cy + k))
        path.addQuadCurve(to: CGPoint(x: cx - r, y: cy), control: CGPoint(x: cx - k, y: cy + k))
        path.addQuadCurve(to: CGPoint(x: cx, y: cy - r), control: CGPoint(x: cx - k, y: cy - k))
        path.closeSubpath()
        ctx.setFillColor(color(p.spark, s.alpha))
        ctx.addPath(path)
        ctx.fillPath()
    }
    ctx.restoreGState()

    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL,
                                                     UTType.png.identifier as CFString, 1, nil)
    else { exit(1) }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { exit(1) }
}

// MARK: - Entry

if A.count >= 3, A[1] == "--svg" {
    try writeSVGs(A[2])
} else if A.count >= 4, A[1] == "--png" {
    let p = A.contains("--dark") ? dark : (A.contains("--tinted") ? tinted : light)
    try writePNG(A[2], Double(A[3]) ?? 1024, p)
} else {
    FileHandle.standardError.write(Data("""
    usage: make-icon.swift --png <out.png> <size> [--dark|--tinted]
           make-icon.swift --svg <dir>

    """.utf8))
    exit(2)
}
