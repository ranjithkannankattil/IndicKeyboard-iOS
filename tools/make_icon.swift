// Draws the 1024×1024 app icon: a Malayalam "ര" keycap above a row of keys.
// Usage: swift make_icon.swift <output.png>
import AppKit
import CoreText

let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Flip to top-left origin so coordinates match the design.
ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)

func rgb(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((h >> 16) & 255) / 255, green: CGFloat((h >> 8) & 255) / 255,
            blue: CGFloat(h & 255) / 255, alpha: a)
}
func rr(_ r: CGRect, _ rad: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil) }

// Background gradient
let bg = CGGradient(colorsSpace: cs, colors: [rgb(0x2F7BFF), rgb(0x1450D8), rgb(0x0B2F96)] as CFArray, locations: [0, 0.55, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 180, y: 0), end: CGPoint(x: 844, y: S), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// Big keycap: soft shadow, base edge, gradient face
let cap = CGRect(x: 212, y: 150, width: 600, height: 520)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -50), blur: 80, color: rgb(0x00001E, 0.45))
ctx.addPath(rr(cap.offsetBy(dx: 0, dy: 26), 110)); ctx.setFillColor(rgb(0xA9B8D6)); ctx.fillPath()
ctx.restoreGState()
ctx.addPath(rr(cap.offsetBy(dx: 0, dy: 26), 110)); ctx.setFillColor(rgb(0xA9B8D6)); ctx.fillPath()
ctx.saveGState()
ctx.addPath(rr(cap, 110)); ctx.clip()
let face = CGGradient(colorsSpace: cs, colors: [rgb(0xFFFFFF), rgb(0xE9EEF7)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(face, start: CGPoint(x: 0, y: cap.minY), end: CGPoint(x: 0, y: cap.maxY), options: [])
ctx.restoreGState()

// Letter അ, centred on its glyph bounds
let fontName = ["Manjari-Bold", "MalayalamSangamMN-Bold", "MalayalamMN-Bold"].first { NSFont(name: $0, size: 10) != nil } ?? "MalayalamSangamMN"
let font = CTFontCreateWithName(fontName as CFString, 560, nil)
let str = NSAttributedString(string: "ര", attributes: [.init(kCTFontAttributeName as String): font,
                                                       .init(kCTForegroundColorAttributeName as String): rgb(0x123A9C)])
let line = CTLineCreateWithAttributedString(str)
let gb = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
ctx.saveGState()
ctx.translateBy(x: cap.midX, y: cap.midY + 6); ctx.scaleBy(x: 1, y: -1)
ctx.textPosition = CGPoint(x: -gb.midX, y: -gb.midY)
CTLineDraw(line, ctx)
ctx.restoreGState()

// Row of small keys: key, space bar, key
let ks: [(CGFloat, CGFloat)] = [(150, 126), (310, 404), (748, 126)]
for (x, w) in ks {
    let r = CGRect(x: x, y: 765, width: w, height: 110)
    ctx.addPath(rr(r.offsetBy(dx: 0, dy: 10), 30)); ctx.setFillColor(rgb(0x0A1E64, 0.45)); ctx.fillPath()
    ctx.addPath(rr(r, 30)); ctx.setFillColor(rgb(0xE3E9F7)); ctx.fillPath()
}

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("icon written with font", fontName)
