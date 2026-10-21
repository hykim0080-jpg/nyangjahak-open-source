import AppKit
import CoreGraphics

// Renders the 1024×1024 app icon: a box lid seen from above, open a crack,
// with two glints and a paw slipping out of the dark gap.

let size = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Draw in top-left coordinates like the prototype.
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
func poly(_ pts: [(CGFloat, CGFloat)], _ fill: CGColor) {
    ctx.beginPath()
    ctx.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
    for p in pts.dropFirst() { ctx.addLine(to: CGPoint(x: p.0, y: p.1)) }
    ctx.closePath()
    ctx.setFillColor(fill)
    ctx.fillPath()
}
func oval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ fill: CGColor) {
    ctx.setFillColor(fill)
    ctx.fillEllipse(in: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
}

// Ground: the lid fills the icon.
ctx.setFillColor(color(0xD6AE7E))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// The dark gap between the two flaps, widest at the top where the lid is pushed open.
poly([(360, 0), (680, 0), (570, 700), (470, 700)], color(0x1A130D))
// A little depth on the gap's walls.
poly([(360, 0), (420, 0), (490, 700), (470, 700)], color(0x2A1F16))

// Left flap edge and right flap (slightly lifted, so a touch darker).
poly([(0, 0), (360, 0), (470, 700), (470, 1024), (0, 1024)], color(0xD6AE7E))
poly([(680, 0), (1024, 0), (1024, 1024), (556, 1024), (570, 700)], color(0xCDA372))
ctx.setStrokeColor(color(0xB48A58))
ctx.setLineWidth(6)
ctx.beginPath()
ctx.move(to: CGPoint(x: 360, y: 0)); ctx.addLine(to: CGPoint(x: 470, y: 700)); ctx.addLine(to: CGPoint(x: 470, y: 1024))
ctx.move(to: CGPoint(x: 680, y: 0)); ctx.addLine(to: CGPoint(x: 570, y: 700)); ctx.addLine(to: CGPoint(x: 556, y: 1024))
ctx.strokePath()

// Packing tape still holding the bottom half, torn where the gap opens.
poly([(440, 1024), (586, 1024), (586, 712), (566, 730), (546, 710), (526, 730), (506, 710), (486, 730), (466, 710), (440, 726)], color(0xEBD8B0, 0.95))

// Two glints watching from the dark.
oval(470, 230, 38, 17, color(0xE8D9A0, 0.95))
oval(570, 218, 38, 17, color(0xE8D9A0, 0.95))

// A paw slipping out over the left flap: a rounded arm with three toes.
let ink = color(0x120E0B)
ctx.saveGState()
ctx.translateBy(x: 470, y: 430)
ctx.rotate(by: 150 * .pi / 180)
ctx.scaleBy(x: 1.45, y: 1.45)
ctx.setFillColor(ink)
ctx.addPath(CGPath(roundedRect: CGRect(x: -20, y: -38, width: 150, height: 76), cornerWidth: 38, cornerHeight: 38, transform: nil))
ctx.fillPath()
// Round pad at the end of the arm, toes along its rim.
ctx.fillEllipse(in: CGRect(x: 118 - 48, y: -46, width: 96, height: 92))
for (x, y) in [(150.0, -40.0), (170.0, -14.0), (170.0, 14.0), (150.0, 40.0)] as [(CGFloat, CGFloat)] {
    ctx.fillEllipse(in: CGRect(x: x - 16, y: y - 16, width: 32, height: 32))
}
ctx.restoreGState()

// Write the PNG.
let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
