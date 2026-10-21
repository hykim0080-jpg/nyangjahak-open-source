import SwiftUI

// MARK: Start

struct StartView: View {
    @EnvironmentObject var store: GameStore
    @State private var mode: TransportMode = .byDuration
    @State private var minutes: Double = 50
    @State private var arrival = StartView.defaultArrival()
    /// The longest a box can be carried when set by arrival time.
    private static let maxArrivalMinutes = 12 * 60.0
    @State private var now = Date.now
    private let clockTick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var durations: [(String, Double)] {
        var list: [Double] = [25, 50, 100, 120]
        #if DEBUG
        if !screenshotMode { list.insert(1, at: 0) }
        #endif
        return list.map { (durationLabel($0), $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("냥자역학").font(Fonts.display(19))
                Spacer()
                SettingsButton()
                if !store.boxes.isEmpty || !store.cats.isEmpty {
                    Button("창고") { store.screen = .warehouse }
                        .font(Fonts.body(14, .semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0x1E2632))
                    .overlay(RoundedRectangle(cornerRadius: 7).fill(Color(hex: 0x2B3644)).padding(4))
                    .frame(width: 46, height: 88)
                    .rotationEffect(.degrees(-8))
                    .offset(y: -44)
                RoundedRectangle(cornerRadius: 3).fill(Palette.cardboard)
                    .overlay(alignment: .top) { Rectangle().fill(Palette.inside).frame(height: 8) }
                    .frame(width: 150, height: 96)
                    .offset(y: 30)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .accessibilityHidden(true)

            Text("오늘 옮길 상자").font(Fonts.display(28)).foregroundStyle(Palette.ink).padding(.top, 8)
            Text("휴대폰을 상자에 넣고 창고까지 옮겨요. 가는 동안 상자는 닫혀 있어야 해요.")
                .font(Fonts.body(14)).foregroundStyle(Palette.inkSoft).padding(.top, 6)

            VStack(spacing: 10) {
                ForEach(TransportMode.allCases) { m in
                    Button { mode = m } label: {
                        HStack(spacing: 12) {
                            Image(systemName: m.symbol)
                                .font(.system(size: 18))
                                .foregroundStyle(Color(hex: 0x6E5034))
                                .frame(width: 40, height: 40)
                                .background(Color(hex: 0xEFE5D6), in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.label).font(Fonts.body(15, .semibold)).foregroundStyle(Palette.ink)
                                Text(m.subtitle).font(Fonts.body(12)).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(mode == m ? Palette.paper : Color(hex: 0xF7F3EC), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(mode == m ? Palette.button : Color(hex: 0xE2D9CC), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 18)

            switch mode {
            case .byDuration: durationPicker
            case .byArrival: arrivalPicker
            case .untilOpen: untilOpenNote
            }

            if store.bonusNext && !store.isBlocked(at: now) {
                Label("지난번 빈 상자를 끝까지 옮겨서, 이번 상자는 귀한 고양이를 만나기 쉬워요", systemImage: "sparkles")
                    .font(Fonts.body(12, .medium)).foregroundStyle(Color(hex: 0x6E5034))
                    .padding(.top, 10)
            }

            Spacer(minLength: 16)
            if store.isBlocked(at: now), let until = store.blockedUntil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("그만둔 상자가 아직 길 위에 있어요").font(Fonts.body(14, .semibold)).foregroundStyle(Palette.ink)
                    Text("원래 도착 시간까지 \(clock(until.timeIntervalSince(now))) 남았어요. 그때까지 새 상자를 받을 수 없어요.")
                        .font(Fonts.body(13)).foregroundStyle(Palette.inkSoft)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: 0xEFE5D6), in: RoundedRectangle(cornerRadius: 14))
                .padding(.bottom, 10)
            }
            PrimaryButton(title: "상자에 넣고 닫기") {
                store.packSnapshot = ScreenSnapshot.take()
                store.beginPacking(mode: mode, minutes: mode == .byArrival ? arrivalMinutes : minutes)
            }
                .disabled(store.isBlocked(at: now))
                .opacity(store.isBlocked(at: now) ? 0.4 : 1)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .background(Palette.ground.ignoresSafeArea())
        .onReceive(clockTick) { now = $0 }
    }

    // MARK: Until open

    private var untilOpenNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("상자 속은 열기 전까지 알 수 없어요. 오래 고요할수록 무언가 자리 잡을 가능성이 커져요.")
                .font(Fonts.body(14)).foregroundStyle(Palette.inkSoft)
            Text("열 때마다 그동안 무언가 자리 잡았는지 정해져요. 확인하고 다시 닫아도 되고, 그대로 창고로 보내도 돼요. 12시간이 지나면 저절로 창고로 가요.")
                .font(Fonts.body(12)).foregroundStyle(Palette.muted)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 18)
    }

    // MARK: By duration

    @ViewBuilder private var durationPicker: some View {
            HStack(alignment: .firstTextBaseline) {
                Text("운반 시간").font(Fonts.body(12, .semibold)).foregroundStyle(Palette.muted)
                Spacer()
                Text(durationLabel(minutes)).font(Fonts.body(20, .semibold)).monospacedDigit().foregroundStyle(Palette.ink)
            }
            .padding(.top, 16)
            Slider(value: $minutes, in: 5...240, step: 5)
                .tint(Palette.button)
                .accessibilityLabel("운반 시간")
                .accessibilityValue(durationLabel(minutes))
            HStack(spacing: 8) {
                ForEach(durations, id: \.1) { label, value in
                    Button { minutes = value } label: {
                        Text(label)
                            .font(Fonts.body(13, .semibold))
                            .foregroundStyle(minutes == value ? Palette.buttonText : Palette.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(minutes == value ? Palette.button : Palette.paper, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(minutes == value ? Palette.button : Color(hex: 0xE2D9CC), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
    }

    // MARK: By arrival time

    /// Minutes from now until the chosen time (tomorrow if it's already passed today), at most 12 hours.
    /// Minutes until the chosen time, kept exact (not rounded) so the box lands on the minute picked.
    private var arrivalMinutes: Double {
        var target = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: arrival),
                                           minute: Calendar.current.component(.minute, from: arrival),
                                           second: 0, of: now) ?? arrival
        if target <= now { target = target.addingTimeInterval(24 * 3600) }
        let m = target.timeIntervalSince(now) / 60
        return max(5, min(Self.maxArrivalMinutes, m))
    }

    @ViewBuilder private var arrivalPicker: some View {
        HStack(alignment: .center) {
            Text("도착 시간").font(Fonts.body(12, .semibold)).foregroundStyle(Palette.muted)
            Spacer()
            DatePicker("도착 시간", selection: $arrival, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(Palette.button)
        }
        .padding(.top, 16)
        Text("지금부터 \(durationLabel(arrivalMinutes)) 동안 옮겨요")
            .font(Fonts.body(13)).foregroundStyle(Palette.inkSoft)
            .padding(.top, 6)
        if arrivalMinutes >= Self.maxArrivalMinutes {
            Text("한 번에 12시간까지 옮길 수 있어요")
                .font(Fonts.body(12)).foregroundStyle(Palette.riskText)
                .padding(.top, 2)
        }
    }

    /// Tomorrow 7:00 in the evening and at night; otherwise two hours from now, on the half hour.
    static func defaultArrival(from now: Date = .now) -> Date {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        if hour >= 18 || hour < 4 {
            return cal.date(bySettingHour: 7, minute: 0, second: 0, of: now) ?? now
        }
        let later = now.addingTimeInterval(2 * 3600)
        let m = cal.component(.minute, from: later)
        return cal.date(bySettingHour: cal.component(.hour, from: later), minute: m < 30 ? 30 : 0, second: 0, of: later)
            .map { m < 30 ? $0 : $0.addingTimeInterval(3600) } ?? later
    }
}

func durationLabel(_ minutes: Double) -> String {
    let m = Int(minutes.rounded(.up))
    if m < 60 { return String(localized: "\(m)분", bundle: .localized) }
    return m % 60 == 0 ? String(localized: "\(m / 60)시간", bundle: .localized) : String(localized: "\(m / 60)시간 \(m % 60)분", bundle: .localized)
}

// MARK: Pack

private func clamp01(_ x: Double) -> Double { max(0, min(1, x)) }
private func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
private func easeInOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }

/// Grabs what's on screen right now, for the shrink-into-the-box effect.
enum ScreenSnapshot {
    static func take() -> UIImage? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).flatMap(\.windows).first(where: \.isKeyWindow) else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: false) }
    }
}

/// The full screen turning into a phone: it shrinks from edge to edge down to the phone's spot in the
/// box, its corners round off, a dark frame grows around it, and its picture dims into the phone's screen.
struct ShrinkingScreen: View {
    let image: UIImage
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            let s = max(geo.size.width / designSize.width, geo.size.height / designSize.height)
            let ox = (geo.size.width - designSize.width * s) / 2, oy = (geo.size.height - designSize.height * s) / 2
            // Where the drawn phone rests in the box, in screen points.
            let target = CGRect(x: ox + 125 * s, y: oy + 190 * s, width: 140 * s, height: 264 * s)
            let full = CGRect(origin: .zero, size: geo.size)
            let q = easeInOut(progress)
            // A little float upward first, as if lifted, then down into the box.
            let lift = -28 * sin(.pi * min(1, progress * 1.6)) * (1 - q)
            let r = CGRect(x: full.minX + (target.minX - full.minX) * q,
                           y: full.minY + (target.minY - full.minY) * q + lift,
                           width: full.width + (target.width - full.width) * q,
                           height: full.height + (target.height - full.height) * q)
            let bezel = 8 * s * q
            let corner = 50 + (24 * s - 50) * q
            ZStack {
                RoundedRectangle(cornerRadius: corner).fill(Color(hex: 0x1E2632))
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: r.width - 2 * bezel, height: r.height - 2 * bezel)
                    .clipShape(RoundedRectangle(cornerRadius: max(4, corner - bezel)))
                    .overlay(RoundedRectangle(cornerRadius: max(4, corner - bezel))
                        .fill(Color(hex: 0x2B3644).opacity(clamp01((progress - 0.6) / 0.35))))
            }
            .frame(width: r.width, height: r.height)
            .shadow(color: .black.opacity(0.35 * q), radius: 12 * q, y: 6 * q)
            .position(x: r.midX, y: r.midY)
        }
        .ignoresSafeArea()
    }
}

/// Phone drops in, flaps fold, a black streak slips through the last gap, then the lid fills the screen.
struct PackView: View {
    @EnvironmentObject var store: GameStore
    @State private var start = Date.now
    @State private var finished = false

    private let launch = 3250.0, dash = 340.0
    /// How long the screen takes to shrink into the phone in the box.
    static let shrinkEnd = 950.0
    private var snapAt: Double { launch + dash }

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSince(start) * 1000
            let zp = easeInOut(clamp01((t - (snapAt + 700)) / 900))
            ZStack {
                DesignCanvas(background: Color(hex: 0x3F342B)) {
                    ZStack {
                        packArt(t)
                            .scaleEffect(1 + 1.25 * zp, anchor: UnitPoint(x: 195 / 390, y: 325 / 844))
                        LidArt().opacity(clamp01((zp - 0.55) / 0.45))
                    }
                }
                // The screen you were just looking at shrinks into the phone and drops into the box.
                if let shot = store.packSnapshot, t < Self.shrinkEnd {
                    ShrinkingScreen(image: shot, progress: clamp01(t / Self.shrinkEnd))
                        .allowsHitTesting(false)
                }
                VStack {
                    Spacer()
                    if zp < 1 {
                        Card {
                            Group {
                                if store.transport?.mode == .untilOpen {
                                    Text(TransportMode.untilOpen.label)
                                } else {
                                    Text("\(store.transport?.mode.label ?? "") · \(Int((store.transport?.duration ?? 0) / 60))분")
                                }
                            }
                                .font(Fonts.body(12, .semibold)).foregroundStyle(Palette.muted)
                            Text(t >= snapAt ? "상자를 닫았어요" : t >= 1300 ? "상자를 닫는 중…" : "휴대폰을 상자에 넣어요")
                                .font(Fonts.display(26)).foregroundStyle(Palette.ink)
                            Text("방금, 무언가 같이 들어간 것 같은데.")
                                .font(Fonts.body(14)).foregroundStyle(Palette.inkSoft)
                                .opacity(t >= snapAt + 500 ? 1 : 0)
                        }
                        .opacity(1 - clamp01(zp / 0.4))
                        .offset(y: 60 * clamp01(zp / 0.4))
                    } else {
                        VStack(spacing: 14) {
                            Spacer()
                            VStack(alignment: .leading, spacing: 6) {
                                Text("배송 라벨 · \(store.transport?.mode.label ?? "")")
                                    .font(Fonts.body(11, .semibold)).foregroundStyle(Color(hex: 0x7A6A58))
                                Text("휴대폰 1대 (그 밖엔 모름)").font(Fonts.display(22)).foregroundStyle(Palette.ink)
                                Text("방금, 무언가 같이 들어간 것 같은데.").font(Fonts.body(13)).foregroundStyle(Palette.inkSoft)
                            }
                            .padding(.horizontal, 20).padding(.vertical, 18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 8))
                            .rotationEffect(.degrees(-2))
                            Color.clear.frame(height: 54)
                        }
                    }
                }
                .padding(16)
            }
        }
        .overlay(alignment: .bottom) {
            if finished {
                HStack(spacing: 10) {
                    PrimaryButton(title: "폰을 엎고 출발하기") { store.startCarrying() }
                    SecondaryButton(title: "다시 보기") { replay() }
                        .frame(width: 110)
                }
                .padding(16)
            }
        }
        .onAppear { replay() }
    }

    private func replay() {
        start = .now
        finished = false
        let startedAt = start
        DispatchQueue.main.asyncAfter(deadline: .now() + (snapAt + 1650) / 1000) {
            if start == startedAt { finished = true }
        }
    }

    private func packArt(_ t: Double) -> some View {
        Canvas { ctx, _ in
            func poly(_ pts: [(Double, Double)]) -> Path {
                var p = Path()
                p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
                for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
                p.closeSubpath()
                return p
            }
            ctx.fill(Path(CGRect(x: 48, y: 130, width: 294, height: 390)), with: .color(Palette.inside))
            ctx.fill(poly([(48, 130), (342, 130), (326, 156), (64, 156)]), with: .color(Palette.wallTop))
            ctx.fill(poly([(48, 130), (64, 156), (64, 500), (48, 520)]), with: .color(Palette.wallSide))
            ctx.fill(poly([(342, 130), (326, 156), (326, 500), (342, 520)]), with: .color(Palette.wallSide))
            ctx.fill(poly([(48, 520), (64, 500), (326, 500), (342, 520)]), with: .color(Palette.wallBottom))

            // Phone dropping in; after the shrinking screen, it is simply there.
            let phoneTop = store.packSnapshot != nil
                ? (t < Self.shrinkEnd - 120 ? -1000 : 190)
                : -320 + 510 * easeOut(clamp01((t - 400) / 600))
            ctx.fill(Path(roundedRect: CGRect(x: 125, y: phoneTop, width: 140, height: 264), cornerRadius: 24), with: .color(Color(hex: 0x1E2632)))
            ctx.fill(Path(roundedRect: CGRect(x: 133, y: phoneTop + 8, width: 124, height: 248), cornerRadius: 17), with: .color(Color(hex: 0x2B3644)))

            // Short flaps fold in first.
            let fold = easeInOut(clamp01((t - 1300) / 600))
            let f = -130 + 190 * fold, g = -90 + 150 * fold
            let kx = 48 * max(0, -f) / 130, kx2 = 48 * max(0, -g) / 90
            ctx.fill(poly([(48, 130), (342, 130), (342 + kx, 130 + f), (48 - kx, 130 + f)]), with: .color(f < 0 ? Palette.flapLight : Color(hex: 0xC99F6C)))
            ctx.fill(poly([(48, 520), (342, 520), (342 + kx2, 520 - g), (48 - kx2, 520 - g)]), with: .color(g < 0 ? Palette.flapBottom : Color(hex: 0xC99F6C)))

            // The streak slips through the closing gap.
            let q = easeOut(clamp01((t - launch) / dash))
            if t >= launch && t < snapAt + 40 {
                var s = ctx
                s.translateBy(x: -220 + 317 * q, y: 760 - 317 * q)
                s.rotate(by: .degrees(-49))
                let ink = Palette.presence
                s.fill(Path(roundedRect: CGRect(x: -150, y: 6, width: 120, height: 3), cornerRadius: 1.5), with: .color(ink.opacity(0.45)))
                s.fill(Path(roundedRect: CGRect(x: -100, y: 16, width: 80, height: 3), cornerRadius: 1.5), with: .color(ink.opacity(0.45)))
                s.fill(Path(roundedRect: CGRect(x: -180, y: 26, width: 140, height: 2), cornerRadius: 1), with: .color(ink.opacity(0.3)))
                s.fill(Path(roundedRect: CGRect(x: 0, y: 0, width: 150, height: 22), cornerRadius: 11), with: .color(ink))
            }

            // Long flaps stand up, slow near the end, then snap shut.
            let e: Double
            if t < 1900 { e = -48 }
            else if t < snapAt { e = -48 + 166 * easeOut(clamp01((t - 1900) / 1300)) }
            else { e = 118 + 29 * clamp01((t - snapAt) / 120) }
            let kt = 130 * max(0, -e) / 48, kb = 90 * max(0, -e) / 48
            let side = e < 0 ? Palette.flapSide : Palette.cardboard
            let left = poly([(48, 130), (48, 520), (48 + e, 520 + kb), (48 + e, 130 - kt)])
            let right = poly([(342, 130), (342, 520), (342 - e, 520 + kb), (342 - e, 130 - kt)])
            ctx.fill(left, with: .color(side)); ctx.stroke(left, with: .color(Color(hex: 0xB48A58)), lineWidth: 1)
            ctx.fill(right, with: .color(side)); ctx.stroke(right, with: .color(Color(hex: 0xB48A58)), lineWidth: 1)
            if t >= snapAt + 500 {
                ctx.fill(Path(CGRect(x: 165, y: 126, width: 60, height: 398)), with: .color(Palette.tape.opacity(0.9)))
            }
        }
        .frame(width: designSize.width, height: designSize.height)
    }
}

// MARK: Transport (closed lid)

struct TransportView: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var motion: MotionMonitor
    @State private var confirmAbandon = false
    /// The screen dims after a while untouched, to save battery on long carries.
    @State private var lastTouch = Date.now
    private static let dimAfter: TimeInterval = 10
    /// How far the lid is pulled open by a swipe up from the bottom: 0 closed, 1 all the way.
    @State private var lift: CGFloat = 0
    @State private var committing = false
    @State private var bottomInset: CGFloat = 34
    /// The swipe distance that opens the lid fully, and with it leaves for the home screen.
    private static let liftTravel: CGFloat = 380

    var body: some View {
        let t = store.transport
        ZStack {
            // Under the lid: the inside of the box, shown as the flaps come up.
            DesignCanvas(background: Palette.inside) { OpenBoxArt() }
            LidFlaps(progress: lift)
            VStack(spacing: 18) {
                HStack {
                    Label("운반 중", systemImage: "shippingbox.fill")
                        .font(Fonts.body(13, .semibold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color(hex: 0xF2C35B), in: Capsule())
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("배송 라벨").font(Fonts.body(11, .semibold)).foregroundStyle(Color(hex: 0x7A6A58))
                        Spacer()
                        Text(t.map { $0.mode == .byArrival
                              ? String(localized: "\(Date.now.addingTimeInterval($0.remaining).formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(AppLanguage.current.locale))) 도착 예정", bundle: .localized)
                              : $0.mode.label } ?? "").font(Fonts.body(11, .semibold)).foregroundStyle(Color(hex: 0x7A6A58))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("내용물").font(Fonts.body(12)).foregroundStyle(Palette.muted)
                        Text("휴대폰 1대 (그 밖엔 모름)").font(Fonts.display(22)).foregroundStyle(Palette.ink)
                    }
                    Divider()
                    if untilOpen {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("옮긴 시간").font(Fonts.body(12)).foregroundStyle(Palette.muted)
                            Text(clock(t?.carried ?? 0))
                                .font(.system(size: 40, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Palette.ink)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Label(CarryStage(minutes: t?.openStretchMinutes ?? 0).whisper, systemImage: "ear")
                                .font(Fonts.body(15, .medium)).foregroundStyle(Palette.inkSoft)
                            if let wear = CarryStage.wearNote(t?.segments?.count ?? 0) {
                                Label(wear, systemImage: "shippingbox")
                                    .font(Fonts.body(13)).foregroundStyle(Palette.muted)
                            }
                        }
                        .padding(.vertical, 6)
                        stat("상태", "알 수 없음")
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("창고 도착까지").font(Fonts.body(12)).foregroundStyle(Palette.muted)
                            Text(clock(t?.remaining ?? 0))
                                .font(.system(size: 40, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Palette.ink)
                        }
                        RouteBar(progress: t?.progress ?? 0)
                        HStack(spacing: 8) {
                            stat("열어본 횟수", "\(t?.opens ?? 0)번")
                            stat("상태", "알 수 없음")
                        }
                    }
                }
                .padding(22)
                .background(Palette.paper, in: RoundedRectangle(cornerRadius: 8))
                .rotationEffect(.degrees(-2))

                VStack(alignment: .leading, spacing: 8) {
                    Text("이 상자 안에 당신의 휴대폰이 들어 있어요.").font(Fonts.display(20)).foregroundStyle(Palette.ink)
                    Text(untilOpen
                         ? "폰을 엎어두거나 이 화면을 켜 둔 채로 두면 상자가 창고로 움직여요. 상자를 열면 그 순간 지금까지의 상자 속이 정해져요. 다시 닫으면 처음부터 다시 시작하고, 열린 동안은 시간이 멈춰요. 엎어 둔 폰을 들어도 5초 안에 다시 엎으면 계속 옮겨요."
                         : "폰을 엎어두거나 이 화면을 켜 둔 채로 두면 상자가 창고로 움직여요. 엎어 둔 폰을 들거나 다른 앱으로 나가면 상자가 열려요. 열 때마다 병이 깨질 수 있고, 오래 열어두면 무언가 빠져나갈 수 있어요.")
                        .font(Fonts.body(14)).foregroundStyle(Palette.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
                SimulatorFlipToggle()
                // An "until open" box ends by opening it, so there's nothing to give up.
                if !untilOpen {
                    Button("운반 그만두기") { confirmAbandon = true }
                        .font(Fonts.body(13, .medium))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(minHeight: 44)
                }
                Color.clear.frame(height: 22)  // room for the open handle
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            // The label and text ride up with the lid and fade.
            .offset(y: -140 * lift)
            .opacity(Double(1 - min(1, lift * 1.6)))
        }
        // Any touch keeps the screen bright for a while longer.
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in lastTouch = .now })
        .overlay {
            TimelineView(.periodic(from: .now, by: 1)) { tl in
                if tl.date.timeIntervalSince(lastTouch) > Self.dimAfter {
                    DimmedCarry(line: dimLine) {
                        withAnimation(.easeOut(duration: 0.3)) { lastTouch = .now }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.8), value: lastTouch)
        }
        // An "until open" box picked up: a few seconds to put it back down.
        .overlay {
            if let lifted = store.liftedAt {
                TimelineView(.periodic(from: lifted, by: 0.25)) { tl in
                    let left = max(1, Int((GameStore.liftGrace - tl.date.timeIntervalSince(lifted)).rounded(.up)))
                    ZStack {
                        Color.black.opacity(0.55).ignoresSafeArea()
                        VStack(spacing: 10) {
                            Text("\(left)").font(.system(size: 64, weight: .semibold).monospacedDigit())
                            Text("내려놓으면 계속 옮겨요").font(Fonts.body(17, .semibold))
                            Text("그대로 두면 상자가 열려요").font(Fonts.body(13)).opacity(0.8)
                        }
                        .foregroundStyle(.white)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.liftedAt)
        // At the very bottom, where iOS's own swipe home begins: a handle that pulls the lid open.
        .overlay(alignment: .bottom) {
            // Drawn right on top of the home indicator; the touch area is taller and runs to the very
            // bottom edge, so reaching for the home bar lands here too.
            OpenHandle(lift: lift)
                .padding(.horizontal, 24)
                // A fixed strip, slid down over the home indicator. (Ignoring the safe area here
                // made the strip cover the whole screen and swallow every tap.)
                .frame(height: 70, alignment: .bottom)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in pull(v) }
                    .onEnded { v in release(v) })
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { store.openBox() }
                .offset(y: bottomInset - 14)
        }
        // The first swipe from the bottom edge comes here, so it can lift the lid; reaching the top then goes home.
        .defersSystemGestures(on: .bottom)
        .modifier(BottomInsetReader(inset: $bottomInset))
        .onAppear { lastTouch = .now; lift = 0; committing = false }
        .confirmationDialog("운반을 그만둘까요?", isPresented: $confirmAbandon, titleVisibility: .visible) {
            Button("그만두기", role: .destructive) { store.abandon() }
        } message: {
            Text("이 상자는 찌그러진 채 창고에 쌓이고, 원래 도착 시간까지 새 상자를 받을 수 없어요.")
        }
    }


    private var untilOpen: Bool { store.transport?.mode == .untilOpen }

    private var dimLine: String {
        guard let t = store.transport else { return "" }
        return untilOpen
            ? String(localized: "\(clock(t.carried)) 옮기는 중", bundle: .localized)
            : String(localized: "창고까지 \(clock(t.remaining))", bundle: .localized)
    }

    private func pull(_ v: DragGesture.Value) {
        lastTouch = .now
        guard !committing else { return }
        let p = max(0, -v.translation.height) / Self.liftTravel
        lift = min(1, p)
        // All the way up: the lid comes off and the box is open, here in the app.
        if p >= 1 { commit() }
    }

    private func release(_ v: DragGesture.Value) {
        guard !committing else { return }
        let moved = hypot(v.translation.width, v.translation.height)
        if moved < 8 || -v.predictedEndTranslation.height > Self.liftTravel * 1.25 {
            // A plain tap, or a fast flick, counts as all the way.
            commit()
        } else {
            // Let go too soon: the lid drops back shut.
            withAnimation(.spring(response: 0.35, dampingFraction: 0.68)) { lift = 0 }
        }
    }

    private func commit() {
        committing = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeOut(duration: 0.22)) { lift = 1 }
        // First a look inside; from there a second swipe goes to the home screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { store.openBox() }
    }

    private func stat(_ label: LocalizedStringKey, _ value: LocalizedStringKey) -> some View {
        HStack {
            Text(label).foregroundStyle(Palette.muted)
                .lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Text(value).fontWeight(.semibold).foregroundStyle(Palette.ink)
                .lineLimit(1).fixedSize()
        }
        .font(Fonts.body(12))
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(hex: 0xF1ECE4), in: RoundedRectangle(cornerRadius: 6))
    }
}

/// The bottom safe-area inset, read from SwiftUI's layout. (Asking UIKit's window for it while the
/// body is being built left the whole screen ignoring taps.)
struct BottomInsetReader: ViewModifier {
    @Binding var inset: CGFloat

    func body(content: Content) -> some View {
        content.background(GeometryReader { g in
            Color.clear
                .onAppear { inset = g.safeAreaInsets.bottom }
                .onChange(of: g.safeAreaInsets.bottom) { _, v in inset = v }
        })
    }
}

/// The closed lid split down the tape into two flaps that swing up and out as `progress` goes to 1.
struct LidFlaps: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let angle = Double(progress) * 82
            HStack(spacing: 0) {
                DesignCanvas { LidArt() }
                    .frame(width: w, height: h)
                    .frame(width: w / 2, alignment: .leading).clipped()
                    .brightness(-0.18 * Double(progress))
                    .rotation3DEffect(.degrees(angle), axis: (0, 1, 0), anchor: .leading, perspective: 0.6)
                DesignCanvas { LidArt() }
                    .frame(width: w, height: h)
                    .frame(width: w / 2, alignment: .trailing).clipped()
                    .brightness(-0.18 * Double(progress))
                    .rotation3DEffect(.degrees(-angle), axis: (0, 1, 0), anchor: .trailing, perspective: 0.6)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// The pull tab at the bottom of the carry screen: just a faint chevron and a line of small text
/// sitting on the home indicator, so it reads as part of the box rather than a button.
struct OpenHandle: View {
    let lift: CGFloat
    var idle: LocalizedStringKey = "위로 밀어서 상자 열기"
    var pulling: LocalizedStringKey = "끝까지 올리면 상자가 열려요"

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: "chevron.compact.up")
                .font(.system(size: 18, weight: .semibold))
                .offset(y: -6 * lift)
            Text(lift > 0.02 ? pulling : idle)
                .font(Fonts.body(10, .medium))
        }
        .foregroundStyle(Palette.ink.opacity(0.32 + 0.4 * Double(lift)))
        .frame(maxWidth: .infinity)
    }
}

/// The carry screen with the lights down: nearly black, only the time left showing faintly.
/// Black pixels cost almost nothing on an OLED screen. A tap brings the screen back.
struct DimmedCarry: View {
    let line: String
    var wake: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.94).ignoresSafeArea()
            VStack(spacing: 10) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 22))
                Text(line)
                    .font(.system(size: 17, weight: .semibold).monospacedDigit())
                Text("화면을 누르면 밝아져요")
                    .font(Fonts.body(12))
                    .opacity(0.7)
            }
            .foregroundStyle(Color.white.opacity(0.35))
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: wake)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("화면을 다시 밝게 해요")
    }
}

struct RouteBar: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let x = geo.size.width * progress
                ZStack(alignment: .topLeading) {
                    Path { p in p.move(to: CGPoint(x: 0, y: 31)); p.addLine(to: CGPoint(x: geo.size.width, y: 31)) }
                        .stroke(Color(hex: 0xD8CFC2), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    Capsule().fill(Palette.ink).frame(width: x, height: 3).offset(y: 30)
                    VStack(spacing: 1) {
                        RoundedRectangle(cornerRadius: 3).fill(Palette.cardboard)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.ink, lineWidth: 1.5))
                            .frame(width: 22, height: 17)
                        Capsule().fill(Color(hex: 0x5A4632)).frame(width: 28, height: 4)
                        HStack { Circle().frame(width: 6); Spacer(); Circle().frame(width: 6) }
                            .foregroundStyle(Palette.ink).frame(width: 22, height: 6)
                    }
                    .offset(x: x - 14)
                    .animation(.linear(duration: 0.25), value: progress)
                }
            }
            .frame(height: 36)
            HStack {
                Text("출발"); Spacer(); Text("창고")
            }
            .font(Fonts.body(11)).foregroundStyle(Palette.muted)
        }
    }
}
