import SwiftUI

// All box art is authored in the prototype's 390×844 space and scaled to fill the screen.
let designSize = CGSize(width: 390, height: 844)

struct DesignCanvas<Content: View>: View {
    var background: Color = Palette.cardboard
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let scale = max(geo.size.width / designSize.width, geo.size.height / designSize.height)
            content()
                .frame(width: designSize.width, height: designSize.height)
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(background)
        .ignoresSafeArea()
    }
}

private func poly(_ pts: [(CGFloat, CGFloat)]) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
    for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
    p.closeSubpath()
    return p
}

private func oval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
}

// MARK: Box

/// The closed lid that fills the whole screen while carrying.
struct LidArt: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Palette.cardboard))
            ctx.fill(Path(CGRect(x: 194, y: 0, width: 2, height: 844)), with: .color(Color(hex: 0xB48A58)))
            ctx.fill(Path(CGRect(x: 157, y: 0, width: 76, height: 844)), with: .color(Palette.tape.opacity(0.85)))
            ctx.stroke(Path(CGRect(x: 5, y: 5, width: 380, height: 834)), with: .color(Palette.cardboardEdge), lineWidth: 10)
        }
        .frame(width: designSize.width, height: designSize.height)
    }
}

/// The opened box seen from above: four flaps folded out and the inside.
struct OpenBoxArt: View {
    var body: some View {
        Canvas { ctx, _ in
            ctx.fill(poly([(0, 0), (390, 0), (342, 130), (48, 130)]), with: .color(Palette.flapLight))
            ctx.fill(poly([(0, 0), (48, 130), (48, 520), (0, 610)]), with: .color(Palette.flapSide))
            ctx.fill(poly([(390, 0), (390, 610), (342, 520), (342, 130)]), with: .color(Palette.flapSide))
            ctx.fill(poly([(48, 520), (342, 520), (390, 610), (0, 610)]), with: .color(Palette.flapBottom))
            ctx.fill(poly([(166, 0), (224, 0), (221, 126), (213, 120), (205, 128), (196, 121), (187, 128), (178, 121), (169, 127)]), with: .color(Palette.tape.opacity(0.9)))
            ctx.fill(poly([(168, 524), (177, 530), (186, 523), (195, 531), (204, 523), (213, 530), (222, 524), (226, 610), (164, 610)]), with: .color(Palette.tape.opacity(0.9)))
            ctx.fill(Path(CGRect(x: 48, y: 130, width: 294, height: 390)), with: .color(Palette.inside))
            ctx.fill(poly([(48, 130), (342, 130), (326, 156), (64, 156)]), with: .color(Palette.wallTop))
            ctx.fill(poly([(48, 130), (64, 156), (64, 500), (48, 520)]), with: .color(Palette.wallSide))
            ctx.fill(poly([(342, 130), (326, 156), (326, 500), (342, 520)]), with: .color(Palette.wallSide))
            ctx.fill(poly([(48, 520), (64, 500), (326, 500), (342, 520)]), with: .color(Palette.wallBottom))
        }
        .frame(width: designSize.width, height: designSize.height)
    }
}

// MARK: Vial

struct VialView: View {
    var broken = false

    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 104
            ctx.scaleBy(x: s, y: s)
            let glass = Color(hex: 0xD7E6EA).opacity(0.9)
            if broken {
                ctx.fill(oval(50, 44, 50, 14), with: .color(Color(hex: 0x9CC0A0).opacity(0.45)))
                var bottom = Path()
                bottom.move(to: CGPoint(x: 26, y: 44))
                bottom.addQuadCurve(to: CGPoint(x: 66, y: 44), control: CGPoint(x: 46, y: 64))
                bottom.addLines([CGPoint(x: 60, y: 36), CGPoint(x: 54, y: 41), CGPoint(x: 48, y: 33), CGPoint(x: 42, y: 40), CGPoint(x: 35, y: 34), CGPoint(x: 30, y: 41)])
                bottom.closeSubpath()
                ctx.fill(bottom, with: .color(glass))
                ctx.fill(poly([(78, 14), (92, 20), (86, 34), (72, 28)]), with: .color(glass))
                ctx.fill(poly([(86, 6), (98, 10), (94, 20), (82, 16)]), with: .color(Color(hex: 0xA8794E)))
                for tri in [[(8, 30), (16, 26), (12, 36)], [(74, 46), (84, 44), (80, 54)], [(20, 50), (28, 48), (26, 56)]] as [[(CGFloat, CGFloat)]] {
                    ctx.fill(poly(tri), with: .color(Color(hex: 0xE6EFF2).opacity(0.9)))
                }
            } else {
                ctx.fill(oval(50, 50, 44, 6), with: .color(.black.opacity(0.18)))
                ctx.fill(Path(roundedRect: CGRect(x: 6, y: 14, width: 60, height: 32), cornerRadius: 15), with: .color(glass))
                ctx.fill(Path(roundedRect: CGRect(x: 11, y: 27, width: 50, height: 15), cornerRadius: 7.5), with: .color(Color(hex: 0x9CC0A0).opacity(0.75)))
                ctx.fill(Path(roundedRect: CGRect(x: 64, y: 22, width: 18, height: 16), cornerRadius: 3), with: .color(glass))
                ctx.fill(Path(roundedRect: CGRect(x: 80, y: 20, width: 14, height: 20), cornerRadius: 3), with: .color(Color(hex: 0xA8794E)))
                var shine = Path()
                shine.move(to: CGPoint(x: 16, y: 20))
                shine.addQuadCurve(to: CGPoint(x: 50, y: 20), control: CGPoint(x: 33, y: 16))
                ctx.stroke(shine, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            }
        }
    }
}

// MARK: Presence

/// The black presence hiding in the box corner: breathing mass, peeking paw, swaying tail, two glints.
struct PresenceView: View {
    var limbs = true

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let s = size.width / 140
                ctx.scaleBy(x: s, y: s)
                let ink = GraphicsContext.Shading.color(Palette.presence)

                ctx.fill(Path(CGRect(x: 0, y: 0, width: 140, height: 140)),
                         with: .radialGradient(Gradient(colors: [Color(hex: 0x0F0B08, opacity: 0.75), Color(hex: 0x0F0B08, opacity: 0)]),
                                               center: CGPoint(x: 140, y: 0), startRadius: 0, endRadius: 120))

                if limbs {
                    // Tail sways around where it leaves the shadow.
                    let sway = -8 * (1 - cos(2 * .pi * t / 2.6)) / 2
                    var tailCtx = ctx
                    tailCtx.translateBy(x: 84, y: 16)
                    tailCtx.rotate(by: .degrees(sway))
                    tailCtx.translateBy(x: -84, y: -16)
                    var tail = Path()
                    tail.move(to: CGPoint(x: 84, y: 16))
                    tail.addCurve(to: CGPoint(x: 32, y: 12), control1: CGPoint(x: 64, y: 8), control2: CGPoint(x: 46, y: 20))
                    tail.addCurve(to: CGPoint(x: 33, y: 2), control1: CGPoint(x: 24, y: 7), control2: CGPoint(x: 25, y: 0))
                    tailCtx.stroke(tail, with: ink, style: StrokeStyle(lineWidth: 6, lineCap: .round))

                    // Paw peeks out, now and then slipping back into the shadow.
                    let phase = (t.truncatingRemainder(dividingBy: 5.5)) / 5.5
                    let pull: CGFloat
                    switch phase {
                    case ..<0.5: pull = 0
                    case ..<0.6: pull = CGFloat((phase - 0.5) / 0.1)
                    case ..<0.82: pull = 1
                    case ..<0.92: pull = CGFloat(1 - (phase - 0.82) / 0.1)
                    default: pull = 0
                    }
                    var pawCtx = ctx
                    pawCtx.translateBy(x: 7 * pull, y: -7 * pull)
                    var paw = Path()
                    paw.move(to: CGPoint(x: 98, y: 72))
                    paw.addCurve(to: CGPoint(x: 78, y: 92), control1: CGPoint(x: 90, y: 78), control2: CGPoint(x: 82, y: 84))
                    paw.addCurve(to: CGPoint(x: 88, y: 99), control1: CGPoint(x: 76, y: 98), control2: CGPoint(x: 82, y: 101))
                    paw.addCurve(to: CGPoint(x: 104, y: 80), control1: CGPoint(x: 94, y: 96), control2: CGPoint(x: 100, y: 88))
                    paw.closeSubpath()
                    pawCtx.fill(paw, with: ink)
                    pawCtx.fill(oval(78, 96, 3, 3), with: ink)
                    pawCtx.fill(oval(82, 100, 3, 3), with: ink)
                    pawCtx.fill(oval(87.5, 101, 2.6, 2.6), with: ink)
                }

                // Breathing mass, anchored in the corner.
                let breathe = (1 - cos(2 * .pi * t / 3.4)) / 2
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 1.4))
                    layer.translateBy(x: 140, y: 0)
                    layer.scaleBy(x: 1 + 0.03 * breathe, y: 1 - 0.03 * breathe)
                    layer.translateBy(x: -140, y: 0)
                    var mass = Path()
                    mass.move(to: CGPoint(x: 140, y: 0))
                    mass.addLine(to: CGPoint(x: 140, y: 80))
                    mass.addCurve(to: CGPoint(x: 96, y: 76), control1: CGPoint(x: 128, y: 88), control2: CGPoint(x: 108, y: 86))
                    mass.addCurve(to: CGPoint(x: 80, y: 24), control1: CGPoint(x: 80, y: 64), control2: CGPoint(x: 74, y: 42))
                    mass.addCurve(to: CGPoint(x: 100, y: 0), control1: CGPoint(x: 84, y: 10), control2: CGPoint(x: 92, y: 2))
                    mass.closeSubpath()
                    layer.fill(mass, with: ink)
                }

                let blinkPhase = t.truncatingRemainder(dividingBy: 5) / 5
                let glint = (0.9..<0.95).contains(blinkPhase) ? 0 : 0.55
                ctx.fill(oval(102, 40, 3.2, 1.5), with: .color(Palette.glint.opacity(glint)))
                ctx.fill(oval(117, 37, 3.2, 1.5), with: .color(Palette.glint.opacity(glint)))
            }
        }
    }
}

/// A fast black streak with speed lines, used when the presence slips in or out.
struct StreakView: View {
    var length: CGFloat = 150

    var body: some View {
        ZStack(alignment: .topLeading) {
            Capsule().fill(Palette.presence.opacity(0.45)).frame(width: 120, height: 3).offset(x: -150, y: 6)
            Capsule().fill(Palette.presence.opacity(0.45)).frame(width: 80, height: 3).offset(x: -100, y: 16)
            Capsule().fill(Palette.presence.opacity(0.3)).frame(width: 140, height: 2).offset(x: -180, y: 26)
            Ellipse().fill(Palette.presence.opacity(0.3)).frame(width: 90, height: 26).blur(radius: 4).offset(x: -70, y: 2)
            Capsule().fill(Palette.presence).frame(width: length, height: 22).blur(radius: 0.8)
        }
        .frame(width: length, height: 30, alignment: .topLeading)
    }
}

struct PawPrintsView: View {
    var body: some View {
        Canvas { ctx, _ in
            let ink = GraphicsContext.Shading.color(Color(hex: 0x4E3520).opacity(0.75))
            for (x, y) in [(176.0, 118.0), (206, 100), (214, 64), (240, 40)] {
                var c = ctx
                c.translateBy(x: x, y: y)
                c.rotate(by: .degrees(40))
                c.fill(oval(0, 3, 5.5, 4.5), with: ink)
                for (tx, ty) in [(-5.0, -3.5), (-1.8, -6.5), (1.8, -6.5), (5, -3.5)] {
                    c.fill(oval(tx, ty, 2.2, 2.2), with: ink)
                }
            }
        }
        .frame(width: 262, height: 344)
    }
}

// MARK: Cat

struct CatView: View {
    let look: CatLook
    var shadow = false

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 120
            ctx.scaleBy(x: s, y: s)
            draw(in: ctx, look, shadow: shadow)
            if let split = look.splitBody {
                // The superposition cat: the right half is another cat altogether.
                var half = ctx
                half.clip(to: Path(CGRect(x: 60, y: 0, width: 60, height: 120)))
                var other = look
                other.body = split; other.stripe = split; other.chest = look.splitChest ?? split
                other.ear = Color(hex: 0x4A3F38)
                draw(in: half, other, shadow: false)
            }
        }
    }

    private func star(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
        var p = Path()
        for i in 0..<10 {
            let radius = i.isMultiple(of: 2) ? r : r * 0.45
            let a = Double(i) * .pi / 5 - .pi / 2
            let pt = CGPoint(x: cx + radius * CGFloat(cos(a)), y: cy + radius * CGFloat(sin(a)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    private func draw(in ctx: GraphicsContext, _ l: CatLook, shadow: Bool) {
        let body = l.body.opacity(l.bodyOpacity)
        let chest = l.chest.opacity(l.bodyOpacity)
        let earOuter = l.earOuter ?? l.body

        if shadow { ctx.fill(oval(60, 116, 36, 4), with: .color(.black.opacity(0.14))) }
        if l.ruff { ctx.fill(oval(60, 62, 37, 31), with: .color(body)) }

        var tail = Path()
        tail.move(to: CGPoint(x: 86, y: 104))
        tail.addCurve(to: CGPoint(x: 104, y: 76), control1: CGPoint(x: 108, y: 104), control2: CGPoint(x: 113, y: 86))
        ctx.stroke(tail, with: .color((l.tail ?? l.body).opacity(l.bodyOpacity)), style: StrokeStyle(lineWidth: l.tailWidth, lineCap: .round))

        ctx.fill(oval(60, 88, 30, 26), with: .color(body))

        if l.bodyStripes {
            var p = Path()
            for (x, y, dx, len) in [(40.0, 78.0, 6.0, 10.0), (80, 78, -6, 10), (44, 96, 5, 8), (76, 96, -5, 8)] {
                p.move(to: CGPoint(x: x, y: y))
                p.addQuadCurve(to: CGPoint(x: x, y: y + len), control: CGPoint(x: x + dx, y: y + len / 2 - 1))
            }
            ctx.stroke(p, with: .color(l.stripe), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
        if l.spots {
            for (x, y, r) in [(43.0, 84.0, 3.6), (77, 82, 3.6), (50, 102, 3.2), (71, 103, 3.2), (38, 96, 2.6), (82, 95, 2.6)] {
                ctx.fill(oval(x, y, r, r), with: .color(l.stripe))
            }
        }
        if l.patches {
            ctx.fill(oval(45, 84, 12, 10), with: .color(l.patchA ?? l.body))
            ctx.fill(oval(76, 97, 10, 8), with: .color(l.patchB ?? l.body))
        }
        if l.stars {
            ctx.fill(star(44, 86, 6), with: .color(Color(hex: 0xF2D27A)))
            ctx.fill(star(77, 97, 4.6), with: .color(Color(hex: 0xF2D27A)))
        }
        if l.tape { ctx.fill(Path(CGRect(x: 54, y: 64, width: 12, height: 50)), with: .color(Palette.tape)) }
        if l.ruff { ctx.fill(oval(60, 80, 22, 12), with: .color(chest)) }

        ctx.fill(oval(60, 92, 15, 19), with: .color(chest))
        ctx.fill(oval(50, 112, 8, 5), with: .color(l.paw ?? l.chest))
        ctx.fill(oval(70, 112, 8, 5), with: .color(l.paw ?? l.chest))

        if l.earsUp {
            ctx.fill(poly([(37, 38), (36, 15), (55, 28)]), with: .color(earOuter))
            ctx.fill(poly([(83, 38), (84, 15), (65, 28)]), with: .color(earOuter))
            ctx.fill(poly([(40.5, 33), (40, 21), (50, 28.5)]), with: .color(l.ear))
            ctx.fill(poly([(79.5, 33), (80, 21), (70, 28.5)]), with: .color(l.ear))
        }
        if l.bigEars {
            ctx.fill(poly([(36, 40), (27, 6), (57, 27)]), with: .color(earOuter))
            ctx.fill(poly([(84, 40), (93, 6), (63, 27)]), with: .color(earOuter))
            ctx.fill(poly([(38, 34), (32, 14), (50, 28)]), with: .color(l.ear))
            ctx.fill(poly([(82, 34), (88, 14), (70, 28)]), with: .color(l.ear))
        }
        if l.tufts {
            var p = Path()
            p.move(to: CGPoint(x: 36, y: 15)); p.addLine(to: CGPoint(x: 33, y: 5))
            p.move(to: CGPoint(x: 84, y: 15)); p.addLine(to: CGPoint(x: 87, y: 5))
            ctx.stroke(p, with: .color(earOuter), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }

        ctx.fill(oval(60, 48, 27, 23), with: .color(body))

        if l.folded {
            var p = Path()
            p.move(to: CGPoint(x: 38, y: 34)); p.addQuadCurve(to: CGPoint(x: 55, y: 30), control: CGPoint(x: 44, y: 23)); p.closeSubpath()
            p.move(to: CGPoint(x: 82, y: 34)); p.addQuadCurve(to: CGPoint(x: 65, y: 30), control: CGPoint(x: 76, y: 23)); p.closeSubpath()
            ctx.fill(p, with: .color(earOuter))
        }
        if l.patches {
            ctx.fill(oval(47, 40, 10, 8), with: .color(l.patchA ?? l.body))
            ctx.fill(oval(73, 38, 9, 7), with: .color(l.patchB ?? l.body))
        }
        if l.headStripes {
            var p = Path()
            p.move(to: CGPoint(x: 55, y: 29)); p.addLine(to: CGPoint(x: 56, y: 35))
            p.move(to: CGPoint(x: 60, y: 27)); p.addLine(to: CGPoint(x: 60, y: 34))
            p.move(to: CGPoint(x: 65, y: 29)); p.addLine(to: CGPoint(x: 64, y: 35))
            ctx.stroke(p, with: .color(l.stripe), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        if l.wrinkles {
            var p = Path()
            p.move(to: CGPoint(x: 51, y: 31)); p.addQuadCurve(to: CGPoint(x: 69, y: 31), control: CGPoint(x: 60, y: 28))
            p.move(to: CGPoint(x: 53, y: 36)); p.addQuadCurve(to: CGPoint(x: 67, y: 36), control: CGPoint(x: 60, y: 34))
            ctx.stroke(p, with: .color(l.stripe), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
        if l.stars { ctx.fill(star(60, 32, 4.6), with: .color(Color(hex: 0xF2D27A))) }
        if l.muzzle { ctx.fill(oval(60, 57, 11, 7.5), with: .color(chest)) }
        if l.mask_ { ctx.fill(oval(60, 54, 15, 12), with: .color(l.mask ?? l.body)) }

        ctx.fill(oval(50, 47, 2.6, 3.4), with: .color(l.eyeL))
        ctx.fill(oval(70, 47, 2.6, 3.4), with: .color(l.eyeR))
        ctx.fill(poly([(57.5, 53), (62.5, 53), (60, 56)]), with: .color(l.nose))
    }
}
