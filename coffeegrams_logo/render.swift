// CoffeeGrams logo renderer.
//
// Draws the brand mark — a tilted balance scale weighed down by a pan full of
// coffee beans — in the app's palette (cream / espresso / caramel gold), and
// writes two 1024x1024 PNGs to the current directory:
//
//   • CoffeeGramsIcon.png     — full art on a warm cream field (the app icon)
//   • CoffeeGramsLogoMark.png — the mark on a transparent field (the in-app
//                                header lockup next to the "CoffeeGrams" word)
//
// Run:  swift render.swift
//
// This is a design tool (macOS CoreGraphics), NOT part of the shipping app.

import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

let SIZE = 1024
let cs = CGColorSpaceCreateDeviceRGB()
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor { CGColor(colorSpace: cs, components: [r, g, b, 1])! }
let cream = rgb(0.960, 0.922, 0.863), creamWarm = rgb(0.925, 0.855, 0.745)
let espresso = rgb(0.216, 0.153, 0.106), espressoHi = rgb(0.298, 0.223, 0.161)
let gold = rgb(0.804, 0.545, 0.196), goldHi = rgb(0.886, 0.663, 0.302)

func render(background: Bool, to path: String) {
    let ctx = CGContext(data: nil, width: SIZE, height: SIZE, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    if background {
        let bg = CGGradient(colorsSpace: cs, colors: [cream, creamWarm] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: SIZE), end: CGPoint(x: 0, y: 0), options: [])
    }

    func bean(cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat, angleDeg: CGFloat) {
        ctx.saveGState(); ctx.translateBy(x: cx, y: cy); ctx.rotate(by: angleDeg * .pi / 180)
        let rect = CGRect(x: -w/2, y: -h/2, width: w, height: h)
        ctx.setFillColor(espresso); ctx.fillEllipse(in: rect)
        ctx.saveGState(); ctx.addEllipse(in: rect); ctx.clip()
        let sheen = CGGradient(colorsSpace: cs, colors: [espressoHi, espresso] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(sheen, start: CGPoint(x: 0, y: h/2), end: CGPoint(x: 0, y: -h/3), options: [])
        ctx.restoreGState()
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: h/2 - h*0.14))
        p.addCurve(to: CGPoint(x: 0, y: -h/2 + h*0.14), control1: CGPoint(x: w*0.32, y: h*0.20), control2: CGPoint(x: -w*0.32, y: -h*0.20))
        ctx.setStrokeColor(gold); ctx.setLineWidth(h*0.09); ctx.setLineCap(.round); ctx.addPath(p); ctx.strokePath()
        ctx.restoreGState()
    }
    func roundRect(_ r: CGRect, _ radius: CGFloat, _ color: CGColor) {
        ctx.setFillColor(color); ctx.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)); ctx.fillPath()
    }
    func line(_ a: CGPoint, _ b: CGPoint, _ w: CGFloat, _ c: CGColor) {
        ctx.setStrokeColor(c); ctx.setLineWidth(w); ctx.setLineCap(.round); ctx.move(to: a); ctx.addLine(to: b); ctx.strokePath()
    }
    func pan(_ center: CGPoint, _ r: CGFloat) {
        let p = CGMutablePath()
        p.addArc(center: center, radius: r, startAngle: .pi, endAngle: 2 * .pi, clockwise: false); p.closeSubpath()
        ctx.setFillColor(gold); ctx.addPath(p); ctx.fillPath()
        line(CGPoint(x: center.x - r, y: center.y), CGPoint(x: center.x + r, y: center.y), 12, goldHi)
    }

    // Stand
    roundRect(CGRect(x: 362, y: 236, width: 300, height: 56), 24, gold)
    roundRect(CGRect(x: 494, y: 286, width: 36, height: 360), 12, espresso)

    // Tilted beam (heavy/left side lower)
    let pivot = CGPoint(x: 512, y: 648), L: CGFloat = 236, a = 13.0 * .pi / 180.0
    let leftEnd  = CGPoint(x: pivot.x - L * cos(a), y: pivot.y - L * sin(a))
    let rightEnd = CGPoint(x: pivot.x + L * cos(a), y: pivot.y + L * sin(a))
    line(leftEnd, rightEnd, 34, gold)
    ctx.setFillColor(espresso); ctx.fillEllipse(in: CGRect(x: pivot.x - 30, y: pivot.y - 30, width: 60, height: 60))

    // Pans + strings (each side's two strings meet at the beam end)
    let leftPan = CGPoint(x: leftEnd.x, y: leftEnd.y - 168), rightPan = CGPoint(x: rightEnd.x, y: rightEnd.y - 168), panR: CGFloat = 96
    line(leftEnd,  CGPoint(x: leftPan.x - panR + 8,  y: leftPan.y), 8, espresso)
    line(leftEnd,  CGPoint(x: leftPan.x + panR - 8,  y: leftPan.y), 8, espresso)
    line(rightEnd, CGPoint(x: rightPan.x - panR + 8, y: rightPan.y), 8, espresso)
    line(rightEnd, CGPoint(x: rightPan.x + panR - 8, y: rightPan.y), 8, espresso)
    pan(leftPan, panR); pan(rightPan, panR)

    // Pile of small beans in the heavy (left) pan
    let bx = leftPan.x, by = leftPan.y
    let smalls: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (-46, 18, 12, 64), (-12, 14, -18, 68), (24, 20, 22, 62),
        (52, 30, -8, 60), (-30, 46, 8, 60), (8, 48, -26, 66), (40, 58, 14, 58),
    ]
    for (dx, dy, ang, h) in smalls { bean(cx: bx + dx, cy: by + dy, w: h * 0.72, h: h, angleDeg: ang) }

    let img = ctx.makeImage()!
    let url = URL(fileURLWithPath: path)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
    print("wrote \(url.path)")
}

render(background: true,  to: "CoffeeGramsIcon.png")
render(background: false, to: "CoffeeGramsLogoMark.png")
