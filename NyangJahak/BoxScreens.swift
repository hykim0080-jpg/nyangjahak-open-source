import SwiftUI
import UIKit.UIGestureRecognizerSubclass

// MARK: Open box

struct OpenView: View {
    @EnvironmentObject var store: GameStore
    @State private var exitStart: Date?
    @State private var exiting = false
    /// "폰 쓰러 가기": a short curtain, then the app steps aside to the home screen.
    @State private var leaving = false
    @Environment(\.scenePhase) private var scenePhase
    /// The swipe up from the bottom toward the home screen: 0 at rest, 1 all the way.
    @State private var lift: CGFloat = 0
    @State private var departing = false
    @State private var bottomInset: CGFloat = 34
    private static let liftTravel: CGFloat = 320

    var body: some View {
        let t = store.transport
        let present = t?.hasPresence ?? false
        let reason = t?.emptyReason
        ZStack {
            TimelineView(.animation) { tl in
                let e = exitStart.map { tl.date.timeIntervalSince($0) } ?? 99
                DesignCanvas {
                    ZStack(alignment: .topLeading) {
                        OpenBoxArt()
                        if reason == .left {
                            PawPrintsView()
                                .opacity(min(1, max(0, (e - 0.8) / 0.8)))
                                .offset(x: 64, y: 156)
                        }
                        VialView(broken: reason == .broken)
                            .frame(width: 104, height: 60)
                            .rotationEffect(.degrees(-18))
                            .offset(x: 74, y: 372)
                        if present || e < 0.3 {
                            PresenceView(limbs: present && e >= 99)
                                .frame(width: 216, height: 216)
                                .scaleEffect(e < 0.25 ? 0.9 : 1, anchor: .topTrailing)
                                .offset(x: 110, y: 156)
                        }
                        if e >= 0.3 && e < 0.65 {
                            let q = min(1, (e - 0.3) / 0.3)
                            let eased = q * q
                            StreakView(length: 70 + 100 * eased)
                                .rotationEffect(.degrees(-57), anchor: .topLeading)
                                .offset(x: 262 + 258 * eased, y: 214 - 474 * eased)
                            ForEach(0..<3, id: \.self) { i in
                                let pos = [(262.0, 196.0, 34.0), (236, 222, 24), (290, 230, 20)][i]
                                Circle().fill(Color(hex: 0xB48A58))
                                    .frame(width: pos.2, height: pos.2)
                                    .scaleEffect(0.8 + q)
                                    .opacity(0.55 * (1 - q))
                                    .offset(x: pos.0, y: pos.1)
                            }
                        }
                    }
                    .frame(width: designSize.width, height: designSize.height, alignment: .topLeading)
                }
            }

            VStack(spacing: 0) {
                (Text(untilOpen ? "옮긴 시간 " : "창고까지 ").font(Fonts.body(12)).foregroundStyle(Palette.inkSoft)
                 + Text(clock(untilOpen ? t?.carried ?? 0 : t?.remaining ?? 0)).font(Fonts.body(12, .semibold)).foregroundStyle(Palette.ink))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Palette.paper, in: Capsule())
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Spacer()
                panel(t: t, present: present, reason: reason, exiting: exiting)
                // The swipe-up handle sits in the layout, under the card and down over the home indicator.
                OpenHandle(lift: lift, idle: "위로 밀어서 폰 쓰러 가기", pulling: "끝까지 올려 주세요")
                    .frame(height: 44, alignment: .bottom)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { v in pullHome(v) }
                        .onEnded { v in releaseHome(v) })
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { goUsePhone() }
                    .padding(.bottom, -max(0, bottomInset - 8))
                    .opacity(leaving ? 0 : 1)
            }
            .padding([.horizontal, .top], 16)
        }
        // Pulled up, the open box shrinks away like an app card heading for the home screen.
        .modifier(CardShrink(lift: lift))
        .overlay {
            if leaving {
                LeaveCurtain { withAnimation(.easeOut(duration: 0.3)) { leaving = false } }
                    .transition(.opacity)
            }
        }
        .modifier(BottomInsetReader(inset: $bottomInset))
        // No deferring here: iOS's own swipe home leaves the box open, which is exactly what's wanted.
        .onChange(of: scenePhase) { _, phase in
            // Back from the phone: lift the curtain to show the box, still open.
            if phase == .active && leaving { withAnimation(.easeOut(duration: 0.4)) { leaving = false } }
        }
        .onChange(of: store.presenceJustLeft) { _, left in
            if left { playExit() }
        }
        .onAppear {
            if store.presenceJustLeft { playExit() }
        }

    }

    private func pullHome(_ v: DragGesture.Value) {
        guard !departing, !leaving else { return }
        let p = max(0, -v.translation.height) / Self.liftTravel
        lift = min(1, p)
        if p >= 1 { departHome() }
    }

    private func releaseHome(_ v: DragGesture.Value) {
        guard !departing else { return }
        if hypot(v.translation.width, v.translation.height) < 8 {
            goUsePhone()  // a tap: same as the "폰 쓰러 가기" button
        } else if -v.predictedEndTranslation.height > Self.liftTravel * 1.25 {
            departHome()
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.68)) { lift = 0 }
        }
    }

    /// Swiped all the way: the card settles back and the curtain shows how to get to the home screen.
    /// (An app can't send itself to the home screen, so the last step is iOS's own swipe.)
    private func departHome() {
        departing = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.18)) { lift = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            departing = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { lift = 0 }
            goUsePhone()
        }
    }

    /// "폰 쓰러 가기": the box is left open behind a curtain that says how to step out.
    private func goUsePhone() {
        withAnimation(.easeIn(duration: 0.35)) { leaving = true }
    }

    private func playExit() {
        exitStart = .now
        exiting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { exiting = false }
    }

    @ViewBuilder
    private func panel(t: Transport?, present: Bool, reason: EmptyReason?, exiting: Bool) -> some View {
        Card {
            HStack {
                Text("관측 결과 · \(t?.opens ?? 0)번째 열기")
                    .font(Fonts.body(12, .semibold)).foregroundStyle(Palette.muted)
                Spacer()
                Text("상자 열림").font(Fonts.body(12)).foregroundStyle(Color(hex: 0x2F5D8C))
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Color(hex: 0xE6EEF6), in: Capsule())
            }
            Text(title(present: present, reason: reason, exiting: exiting))
                .font(Fonts.display(28)).foregroundStyle(Palette.ink)
            Text(message(present: present, reason: reason, exiting: exiting))
                .font(Fonts.body(14)).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if untilOpen, let t {
                let found = (t.segments ?? []).filter(\.present).count
                Text("지금까지 \(t.segments?.count ?? 0)번 열어서 \(found)번 기척을 확인했어요")
                    .font(Fonts.body(12, .medium)).foregroundStyle(Palette.muted)
            } else if present, let t {
                VStack(spacing: 8) {
                    HStack {
                        Text("빠져나갔을 확률 \(Int((store.leaveRisk(openSeconds: t.openSeconds) * 100).rounded()))%").fontWeight(.semibold).foregroundStyle(Palette.riskText)
                        Spacer()
                        Text("열어둔 지 \(shortClock(t.openSeconds))").monospacedDigit().foregroundStyle(Palette.muted)
                    }
                    .font(Fonts.body(12))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(hex: 0xE4DACB))
                            Capsule().fill(Palette.risk)
                                .frame(width: geo.size.width * store.leaveRisk(openSeconds: t.openSeconds))
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color(hex: 0xF4EFE7), in: RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 10) {
                PrimaryButton(title: untilOpen ? "닫고 계속 옮기기" : present ? "닫고 다시 엎기" : "닫고 끝까지 옮기기") { store.closeBox() }
                SecondaryButton(title: "폰 쓰러 가기") { goUsePhone() }
                    .frame(width: 128)
            }
            .padding(.top, 2)
            if untilOpen {
                Button("여기서 창고로 보내기") { store.arriveUntilOpen() }
                    .font(Fonts.body(14, .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            SimulatorFlipToggle()
        }
    }

    private var untilOpen: Bool { store.transport?.mode == .untilOpen }

    private func title(present: Bool, reason: EmptyReason?, exiting: Bool) -> String {
        if untilOpen {
            if present { return String(localized: "무언가 있어요", bundle: .localized) }
            return reason == .broken ? String(localized: "병이 깨져 있어요", bundle: .localized) : String(localized: "비어 있어요", bundle: .localized)
        }
        if present || exiting && reason == .left { return String(localized: "구석에 무언가 있어요", bundle: .localized) }
        return reason == .broken ? String(localized: "병이 깨져 있어요", bundle: .localized) : String(localized: "비어 있어요", bundle: .localized)
    }

    private func message(present: Bool, reason: EmptyReason?, exiting: Bool) -> String {
        if untilOpen {
            if present { return String(localized: "이번에 옮긴 동안 무언가 자리를 잡았어요. 이 기척은 이제 빠져나가지 않아요. 다시 닫으면 상자 속은 처음부터 다시 알 수 없게 돼요.", bundle: .localized) }
            if reason == .broken { return String(localized: "처음 연 순간 구석의 병이 깨졌어요. 병은 이제 더 깨지지 않아요. 다시 닫으면 처음부터 다시 기척이 모여요.", bundle: .localized) }
            return String(localized: "헤진 틈으로 기척이 빠져나갔어요. 다시 닫으면 처음부터 다시 기척이 모이지만, 열수록 상자는 더 헤져요.", bundle: .localized)
        }
        if present || exiting && reason == .left { return String(localized: "어둠 속에서 무언가 숨 쉬는 게 느껴져요. 오래 열어두면 빠져나갈지도 몰라요.", bundle: .localized) }
        if reason == .broken { return String(localized: "구석의 기척은 더 이상 느껴지지 않아요. 이 상자는 열린 채로 창고에 쌓여요. 그래도 끝까지 옮겨 주세요.", bundle: .localized) }
        return String(localized: "열어둔 사이 구석의 기척이 빠져나가고, 작은 발자국만 남았어요. 이 상자는 열린 채로 창고에 쌓여요.", bundle: .localized)
    }
}

/// While pulled up, the screen shrinks into a rounded card over black, like an app heading home.
/// At rest it leaves the view untouched, so nothing clips it or gets in the way of taps.
struct CardShrink: ViewModifier {
    let lift: CGFloat

    func body(content: Content) -> some View {
        if lift > 0.001 {
            content
                .scaleEffect(1 - 0.14 * lift, anchor: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 44 * lift, style: .continuous))
                .background(Color.black.ignoresSafeArea())
        } else {
            content
        }
    }
}

/// A rare find: something other than a cat, tucked in a corner of the box.
struct ItemFindCard: View {
    let item: BoxItem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: item.symbol)
                .font(.system(size: 26))
                .foregroundStyle(item.tint)
                .frame(width: 52, height: 52)
                .background(Color(hex: 0xE9DFD0), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("상자 구석에서 \(item.name)")
                    .font(Fonts.body(14, .semibold)).foregroundStyle(Palette.ink)
                Text(item.note)
                    .font(Fonts.body(12)).foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Palette.paper, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: 0xE2D9CC)))
        .accessibilityElement(children: .combine)
    }
}

/// Shown when going to use the phone: the open box waiting in the dark, something blinking inside it,
/// a line saying it will be left as it is, and a nudge toward iOS's swipe home. Tap to go back to the box.
struct LeaveCurtain: View {
    var back: () -> Void
    @State private var shown = false
    @State private var blink = false
    @State private var nudge = false

    var body: some View {
        ZStack {
            Palette.button.ignoresSafeArea()
            VStack(spacing: 22) {
                ZStack(alignment: .top) {
                    StackBox(open: true, width: 112, height: 84)
                    // Two eyes in the dark of the box, blinking once.
                    HStack(spacing: 14) {
                        ForEach(0..<2, id: \.self) { _ in
                            Capsule().fill(Color(hex: 0xF2C35B))
                                .frame(width: 9, height: blink ? 1.5 : 9)
                        }
                    }
                    .offset(y: 14)
                    .opacity(shown ? 1 : 0)
                }
                VStack(spacing: 8) {
                    Text("상자는 열어둔 채로 둘게요")
                        .font(Fonts.display(24)).foregroundStyle(Palette.buttonText)
                    Text("다녀오세요. 돌아오면 그대로 있어요.")
                        .font(Fonts.body(14)).foregroundStyle(Palette.buttonText.opacity(0.7))
                }
            }
            .scaleEffect(shown ? 1 : 0.94)
            .opacity(shown ? 1 : 0)
            VStack(spacing: 8) {
                Spacer()
                Button("상자로 돌아가기", action: back)
                    .font(Fonts.body(14, .semibold))
                    .foregroundStyle(Palette.buttonText.opacity(0.8))
                    .frame(minHeight: 44)
                    .padding(.bottom, 18)
                VStack(spacing: 2) {
                    Image(systemName: "chevron.compact.up").font(.system(size: 22, weight: .semibold))
                        .offset(y: nudge ? -6 : 0)
                    Text("화면 아래를 쓸어올려 홈 화면으로 가세요").font(Fonts.body(12, .medium))
                }
                .foregroundStyle(Palette.buttonText.opacity(0.55))
                .padding(.bottom, 6)
            }
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.6)) { nudge = true }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15)) { shown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeInOut(duration: 0.12)) { blink = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    withAnimation(.easeInOut(duration: 0.12)) { blink = false }
                }
            }
        }
    }
}

// MARK: Box tile used in stacks

struct StackBox: View {
    var open = false
    var crushed = false
    /// Something rests on top, so an open box's flaps are folded in instead of standing up.
    var covered = false
    var width: CGFloat = 62
    var height: CGFloat = 46

    var body: some View {
        if crushed { crushedBox } else { normalBox }
    }

    /// Abandoned on the way: lid caved in on one side, tape torn, a crease across the front.
    private var crushedBox: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            var body = Path()
            body.move(to: CGPoint(x: 0, y: h * 0.22))
            body.addLine(to: CGPoint(x: w * 0.38, y: h * 0.12))
            body.addLine(to: CGPoint(x: w * 0.56, y: h * 0.34))
            body.addLine(to: CGPoint(x: w, y: h * 0.18))
            body.addLine(to: CGPoint(x: w * 0.97, y: h))
            body.addLine(to: CGPoint(x: w * 0.03, y: h))
            body.closeSubpath()
            ctx.fill(body, with: .color(Color(hex: 0xC49A68)))
            var crease = Path()
            crease.move(to: CGPoint(x: w * 0.56, y: h * 0.34))
            crease.addLine(to: CGPoint(x: w * 0.48, y: h * 0.7))
            crease.addLine(to: CGPoint(x: w * 0.6, y: h))
            ctx.stroke(crease, with: .color(Color(hex: 0x9A7047)), lineWidth: 1.5)
            var tape = Path()
            tape.move(to: CGPoint(x: w * 0.4, y: h * 0.14))
            tape.addLine(to: CGPoint(x: w * 0.52, y: h * 0.3))
            tape.addLine(to: CGPoint(x: w * 0.46, y: h * 0.42))
            tape.addLine(to: CGPoint(x: w * 0.36, y: h * 0.36))
            tape.closeSubpath()
            ctx.fill(tape, with: .color(Palette.tape.opacity(0.85)))
        }
        .frame(width: width, height: height)
        .rotationEffect(.degrees(-4), anchor: .bottom)
        .accessibilityLabel("찌그러진 상자")
    }

    private var normalBox: some View {
        ZStack(alignment: .top) {
            if open && !covered {
                HStack(spacing: 0) {
                    Rectangle().fill(Palette.flapSide).frame(width: width / 2, height: height * 0.45)
                        .rotationEffect(.degrees(-24), anchor: .bottomTrailing)
                    Rectangle().fill(Palette.flapSide).frame(width: width / 2, height: height * 0.45)
                        .rotationEffect(.degrees(24), anchor: .bottomLeading)
                }
                .offset(y: -height * 0.45)
            }
            RoundedRectangle(cornerRadius: 3).fill(Palette.cardboard)
            Rectangle().fill(open ? Palette.inside : Color(hex: 0xE3C297)).frame(height: 8)
            if !open {
                Rectangle().fill(Palette.tape.opacity(0.9)).frame(width: width * 0.22)
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: Arrive

struct ArriveView: View {
    @EnvironmentObject var store: GameStore
    @State private var dropped = false
    @State private var wasEmpty = false
    @State private var info: (minutes: Int, opens: Int) = (0, 0)
    /// Set for an "until open" box: the carry ended by opening it, and this is what was found.
    @State private var observed: EmptyReason?? = nil
    @State private var prior: [StoredBox] = []
    /// The warehouse was full, so stacking this box expands it.
    @State private var expands = false

    private let slots: [(CGFloat, Int)] = [(50, 0), (118, 0), (186, 0), (254, 0), (84, 1), (152, 1), (220, 1), (118, 2)]

    var body: some View {
        VStack(spacing: 0) {
            Text(observed != nil ? "\(durationLabel(Double(info.minutes))) 옮기고 열었어요" : "\(durationLabel(Double(info.minutes))) 운반 완료 · 열어본 횟수 \(info.opens)번")
                .font(Fonts.body(13)).foregroundStyle(Palette.muted)
                .padding(.top, 40)
            Text(dropped ? (expands ? "앞줄을 뒤로 밀었어요" : "상자를 쌓아뒀어요") : observedTitle)
                .font(Fonts.display(30)).foregroundStyle(Palette.ink).padding(.top, 8)
            if wasEmpty || observed == nil {
                Text(wasEmpty ? "빈 상자는 열린 채로 쌓아요." : "도착한 상자는 열지 않고 그대로 쌓아요.")
                    .font(Fonts.body(14)).foregroundStyle(Palette.inkSoft).padding(.top, 8)
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12).fill(Palette.floor)
                    .frame(height: 40).offset(y: 290)
                ForEach(Array(prior.enumerated()), id: \.offset) { i, box in
                    let slot = slots[i]
                    StackBox(open: box.open, crushed: box.isCrushed)
                        .offset(x: slot.0, y: level(slot.1))
                }
                let target = slots[prior.count]
                StackBox(open: wasEmpty)
                    .offset(x: target.0, y: dropped ? level(target.1) : -80)
                    .animation(.interpolatingSpring(stiffness: 180, damping: 14), value: dropped)
            }
            .frame(width: 342, height: 330, alignment: .topLeading)
            .clipped()
            .padding(.top, 28)

            Text(arriveMessage)
                .multilineTextAlignment(.center)
                .font(Fonts.body(14)).foregroundStyle(Palette.inkSoft)
                .opacity(dropped ? 1 : 0)
                .padding(.top, 18)

            if dropped, let found = store.newItem, let item = BoxItem.item(found.itemID) {
                ItemFindCard(item: item)
                    .padding(.top, 16)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            Spacer()
            if dropped {
                PrimaryButton(title: "창고 보러 가기") { store.screen = .warehouse }
            } else {
                PrimaryButton(title: "상자 내려놓기") {
                    store.newItem = nil
                    _ = store.stackArrivedBox()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { dropped = true }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(Palette.ground.ignoresSafeArea())
        .onAppear {
            prior = Array(store.boxes.suffix(slots.count - 1))
            // The rack is full: this box makes the warehouse grow.
            expands = !store.boxes.isEmpty && store.boxes.count == BoxPile.capacity(for: store.boxes.count)
            if let t = store.transport {
                wasEmpty = !t.hasPresence
                info = (Int(t.duration / 60), t.opens)
                if t.mode == .untilOpen { observed = .some(t.hasPresence ? nil : t.emptyReason) }
            }
        }
    }

    private func level(_ l: Int) -> CGFloat { 330 - 40 - 46 - CGFloat(l) * 44 }

    /// For an "until open" box, the title says what opening it revealed.
    private var observedTitle: LocalizedStringKey {
        switch observed {
        case .none: return "창고에 도착했어요"
        case .some(.none): return "무언가 있어요"
        case .some(.some(.broken)): return "병이 깨져 있었어요"
        case .some(.some(_)): return "기척이 빠져나가고 없었어요"
        }
    }

    private var arriveMessage: String {
        if expands {
            let n = store.boxes.count
            return String(localized: "앞줄이 상자 \(BoxPile.step)개로 꽉 찼어요. 쌓인 상자를 뒤로 밀고, 이 상자부터 새 줄에 쌓아요.", bundle: .localized)
        }
        if observed != nil && wasEmpty {
            return String(localized: "조금 더 고요하게 두었다면 달랐을지도 몰라요. 대신 다음 상자에서는 귀한 고양이를 만나기 쉬워져요.", bundle: .localized)
        }
        return wasEmpty ? String(localized: "이번 상자에서는 아무것도 찾아오지 않아요. 그래도 끝까지 옮긴 덕분에 다음 상자에서 귀한 고양이를 만나기 쉬워져요.", bundle: .localized) : String(localized: "창고가 조금 더 찼어요.", bundle: .localized)
    }
}

// MARK: Warehouse

/// Boxes stand in loose stacks on the floor, each box a little smaller than the one under it.
/// A row holds 9 (three stacks of three). When it's full, the whole row is pushed back — smaller,
/// higher up and a touch darker — and the next box starts a new row in front, so the newest
/// boxes are always nearest. Four rows show at most; older ones fade out of sight. One free spot in
/// the front row shows as a faint outline.
struct BoxPile: View, Equatable {
    let boxes: [StoredBox]
    /// 0 shows the warehouse flat, front row only; 1 shows it in depth with the rows behind.
    var mix: CGFloat = 1
    /// Boxes with a cat inside: they rock now and then.
    var occupied: Set<UUID> = []

    static func == (a: BoxPile, b: BoxPile) -> Bool {
        a.mix == b.mix && a.occupied == b.occupied && a.boxes.count == b.boxes.count
            && zip(a.boxes, b.boxes).allSatisfy { $0.id == $1.id && $0.open == $1.open && $0.isCrushed == $1.isCrushed }
    }

    /// A row is three stacks of three; the front row's bottom boxes are about 100pt wide.
    static let stacks = 3
    static let perStack = 3
    static let step = stacks * perStack
    /// Where the front row stands; the cats' floor starts here.
    static let frontBase: CGFloat = 500
    private static let pitch: CGFloat = 118
    private static let boxW: CGFloat = 100
    /// Each row back is drawn this much smaller.
    private static let rowScale: CGFloat = 0.76

    /// 0 for the first 9 boxes, 1 once the 10th arrives, and so on: how many rows sit behind the front one.
    static func level(for count: Int) -> Int { max(0, (count - 1) / step) }
    static func capacity(for count: Int) -> Int { step * (level(for: count) + 1) }
    static func scale(depth d: Int) -> CGFloat { pow(rowScale, CGFloat(d)) }
    /// Rows further back stand higher up the screen, by less each time.
    static func base(depth d: Int) -> CGFloat { frontBase - 30 * (1 - scale(depth: d)) / (1 - rowScale) }
    /// The floor is drawn from just behind the back row.
    static func floorStart(for count: Int) -> CGFloat { base(depth: min(level(for: count), maxDepth)) - 6 }
    /// Only the front row and this many rows behind it are drawn; older rows are out of sight.
    static let maxDepth = 3

    /// Where one box ends up: resting on whatever is already in its stack.
    struct Placed {
        var frame: CGRect
        var tilt: Double
        var depth: Int
        var covered = false
        /// Standing on the floor rather than on another box.
        var grounded = false
    }

    /// A place on a front stack where a cat can be: sitting on top, or tucked inside an open box.
    struct PerchKey: Hashable { let box: UUID; let inside: Bool }
    struct Perch {
        let key: PerchKey
        let frame: CGRect
        /// Inside a box with others stacked on it: the cat disappears into it completely.
        var buried = false
    }

    /// Places on the front row: inside any box that isn't crushed, and on top of each stack.
    static func perches(_ boxes: [StoredBox], mix: CGFloat) -> [Perch] {
        let placed = layout(boxes, mix: mix).boxes
        return boxes.indices.flatMap { i -> [Perch] in
            let p = placed[i]
            guard p.depth == 0, !boxes[i].isCrushed else { return [] }
            let id = boxes[i].id
            var spots: [Perch] = []
            // Any box can be crept into. Only an open box on top lets the cat's head show;
            // into a closed box, or one with others stacked on it, the cat disappears completely.
            let headOut = boxes[i].open && !p.covered
            spots.append(Perch(key: PerchKey(box: id, inside: true), frame: p.frame, buried: !headOut))
            // The top of a stack can also be sat on, if it isn't an open box (that one is climbed into).
            if !p.covered && !boxes[i].open {
                spots.append(Perch(key: PerchKey(box: id, inside: false), frame: p.frame))
            }
            return spots
        }
    }

    private static func seed(_ id: UUID) -> Int {
        id.uuidString.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
    }

    /// Within a row, each box goes on one of the shortest stacks (picked by the box's own seed), so
    /// stacks rise unevenly. Higher boxes are smaller, a crushed box is squat, and whatever lands on
    /// a crushed box sits a bit crooked. The front row's leftover spots are laid out the same way.
    static func layout(_ boxes: [StoredBox], mix: CGFloat) -> (boxes: [Placed], ghosts: [CGRect]) {
        let level = Self.level(for: boxes.count)
        var placed: [Placed] = []
        var ghosts: [CGRect] = []
        for group in 0...level {
            let d = level - group  // the newest row is in front
            // Flat, every row stands on the front line (the rows behind are hidden); in depth they rise behind it.
            let sc = Self.scale(depth: d), base = Self.frontBase - (Self.frontBase - Self.base(depth: d)) * mix
            var counts = Array(repeating: 0, count: Self.stacks)
            var heights = Array(repeating: CGFloat(0), count: Self.stacks)
            var top = Array(repeating: -1, count: Self.stacks)
            let first = group * Self.step
            let last = group == level ? first + Self.step : min(boxes.count, first + Self.step)
            for i in first..<last {
                let box = i < boxes.count ? boxes[i] : nil
                let s = box.map { Self.seed($0.id) } ?? 0
                let low = counts.min() ?? 0
                let candidates = counts.indices.filter { counts[$0] == low }
                let col = box == nil ? candidates[0] : candidates[s % candidates.count]
                let shrink = 1 - 0.17 * CGFloat(counts[col])
                let w = Self.boxW * sc * shrink * (box == nil ? 1 : 0.93 + CGFloat(s % 7) / 100)
                let h = w * (box?.isCrushed == true ? 0.5 : 0.82)
                // Every other row sits half a stack over, so it shows through the gaps of the row in front.
                // Keyed to the row itself, not its depth, so a row pushed back slides straight back.
                let cx0 = designSize.width / 2 + (CGFloat(col) - CGFloat(Self.stacks - 1) / 2 + (group % 2 == 1 ? 0.2 : -0.2)) * Self.pitch
                // Rows converge only gently toward the middle, so back rows stay spread out instead of crowding the centre.
                let spread = 1 - (1 - sc) * 0.35
                let cx = designSize.width / 2 + (cx0 - designSize.width / 2) * spread + (box == nil ? 0 : CGFloat(s % 5 - 2) * sc)
                let rect = CGRect(x: cx - w / 2, y: base - heights[col] - h, width: w, height: h)
                if box != nil {
                    let onCrushed = top[col] >= 0 && boxes[top[col]].isCrushed
                    let tilt = counts[col] == 0 ? 0 : Double(s % 5 - 2) * (onCrushed ? 1.8 : 0.7)
                    if top[col] >= 0 { placed[top[col]].covered = true }  // placed is indexed like boxes
                    placed.append(Placed(frame: rect, tilt: tilt, depth: d, grounded: counts[col] == 0))
                    top[col] = i
                } else {
                    ghosts.append(rect)
                }
                counts[col] += 1
                heights[col] += h - sc
            }
        }
        return (placed, ghosts)
    }

    var body: some View {
        let (placed, ghosts) = Self.layout(boxes, mix: mix)
        ZStack(alignment: .topLeading) {
            // Back rows first; within a row, higher boxes first so the ones under them overlap their edge.
            // The row just past the last visible one is still drawn, fully transparent, so a row being
            // pushed out of sight fades away instead of vanishing.
            rows(placed, where: { $0 >= 1 && $0 <= Self.maxDepth + 1 })
            // The front row sits on soft contact shadows, so it reads as standing on the floor in front.
            ForEach(boxes.indices.filter { placed[$0].depth == 0 && placed[$0].grounded }, id: \.self) { i in
                let r = placed[i].frame
                Ellipse()
                    .fill(.black.opacity(0.16))
                    .frame(width: r.width * 1.12, height: 14)
                    .blur(radius: 4)
                    .offset(x: r.midX - r.width * 0.56, y: r.maxY - 8)
            }
            rows(placed, where: { $0 == 0 })
            // One free spot on a shortest front stack, drawn over the rows behind.
            if let r = ghosts.first {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Palette.ink.opacity(0.22), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    .frame(width: r.width - 4, height: r.height - 4)
                    .offset(x: r.minX + 2, y: r.minY + 2)
            }
        }
        // Flattened into one layer: 90 boxes with shadows are costly to composite every frame cats move.
        // drawingGroup clips to the view's frame, so the frame must reach down to the floor.
        .frame(width: designSize.width, height: Self.frontBase + 6, alignment: .topLeading)
        .drawingGroup()
        .animation(.easeInOut(duration: 0.6), value: Self.level(for: boxes.count))
        .accessibilityHidden(true)
    }

    /// Draws the rows whose depth matches. The front row is crisp and full colour; each row back is
    /// greyer, darker and softer, like things further off in a dim room, so the front row stands out.
    private func rows(_ placed: [Placed], where include: @escaping (Int) -> Bool) -> some View {
        ForEach(Array(boxes.enumerated())
                    .filter { include(placed[$0.offset].depth) }
                    .sorted { (placed[$0.offset].depth, $0.offset) > (placed[$1.offset].depth, $1.offset) },
                id: \.element.id) { i, box in
            let p = placed[i]
            let d = Double(p.depth)
            StackBox(open: box.open, crushed: box.isCrushed, covered: p.covered,
                     width: p.frame.width, height: p.frame.height)
                .rotationEffect(.degrees(p.tilt), anchor: .bottom)
                .modifier(Rocking(active: occupied.contains(box.id), seed: box.id.hashValue))
                .shadow(color: .black.opacity(0.08), radius: 0, y: 1)
                .saturation(p.depth == 0 ? 1.05 : max(0.35, 0.7 - 0.12 * d))
                .brightness(p.depth == 0 ? 0.02 : -0.05 - 0.05 * d)
                .blur(radius: p.depth == 0 ? 0 : 0.5 + 0.6 * d)
                .opacity(p.depth > Self.maxDepth ? 0 : p.depth == 0 ? 1 : Double(mix))
                .offset(x: p.frame.minX, y: p.frame.minY)
        }
    }
}

/// Wooden floor seen at an angle: darker at the back, with board seams that spread apart toward
/// the front and side seams that run toward a vanishing point far behind the boxes.
struct FloorView: View, Equatable {
    let top: CGFloat
    let front: CGFloat
    let height: CGFloat
    /// 0 is a flat band of floor with a plain edge; 1 is the angled wooden floor.
    var mix: CGFloat = 1

    var body: some View {
        Canvas { ctx, size in
            let rect = CGRect(origin: .zero, size: size)
            ctx.fill(Path(rect), with: .color(Palette.floor))
            var depth = ctx
            depth.opacity = Double(mix)
            ctx.stroke(Path { $0.move(to: CGPoint(x: 0, y: 0.5)); $0.addLine(to: CGPoint(x: size.width, y: 0.5)) },
                       with: .color(Palette.wallTop.opacity(0.3 * Double(1 - mix))), lineWidth: 1)
            drawDepth(in: depth, size: size)
        }
        .frame(width: designSize.width, height: height)
    }

    private func drawDepth(in ctx: GraphicsContext, size: CGSize) {
        do {
            let rect = CGRect(origin: .zero, size: size)
            ctx.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [Color(hex: 0xCDB89C), Palette.floor]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: min(size.height, front - top + 40))))
            let seam = Palette.wallTop.opacity(0.13)
            // Cross seams: spacing grows toward the viewer.
            var y: CGFloat = 6, gap: CGFloat = 8
            while y < size.height {
                var line = Path(); line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(line, with: .color(seam), lineWidth: 1)
                y += gap; gap *= 1.35
            }
            // Long seams converge on a point far behind the boxes.
            let vanish = CGPoint(x: size.width / 2, y: -520)
            for i in -6...6 {
                let x = size.width / 2 + CGFloat(i) * 46
                let bottom = CGPoint(x: vanish.x + (x - vanish.x) * (size.height - vanish.y) / (0 - vanish.y), y: size.height)
                var line = Path(); line.move(to: CGPoint(x: x, y: 0)); line.addLine(to: bottom)
                ctx.stroke(line, with: .color(seam.opacity(0.7)), lineWidth: 1)
            }
            // Soft shadow where the floor meets the wall.
            ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: 5)),
                     with: .linearGradient(Gradient(colors: [.black.opacity(0.08), .clear]),
                                           startPoint: .zero, endPoint: CGPoint(x: 0, y: 5)))
        }
    }
}

/// Pinch-to-zoom and drag-to-pan around a fixed-size scene. Its own state changes don't re-run the
/// caller's body, so dragging stays smooth. Zoom 1 fits the width; it can zoom out until the whole scene shows.
struct ZoomPan<Content: View>: View {
    let contentSize: CGSize
    /// How far above the bottom edge the "원래 크기" button sits, clear of the screen's own buttons.
    var resetBottom: CGFloat = 0
    /// A quick swipe (or any drag when there's nothing to pan), as start and end points in content coordinates.
    var onSwipe: ((CGPoint, CGPoint) -> Void)? = nil
    /// Two fingers moved up or down together, rather than apart: how far, in points (negative is up).
    var onTilt: ((TwoFingerTracker.Phase, CGFloat) -> Void)? = nil
    /// A second finger touched down: whatever a single finger had started no longer counts.
    var onTwoFingers: (() -> Void)? = nil
    @ViewBuilder let content: Content

    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var pinchStart: (zoom: CGFloat, pan: CGSize)?
    @State private var dragStart: CGSize?
    @State private var dragBegan: Date?
    @State private var lastTwoFingers = Date.distantPast

    var body: some View {
        GeometryReader { geo in
            let base = geo.size.width / contentSize.width
            let minZoom = max(0.5, min(1, geo.size.height / (contentSize.height * base)))
            content
                .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
                .scaleEffect(base * zoom, anchor: .topLeading)
                .offset(clamped(pan, scale: base * zoom, in: geo.size))
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .clipped()
                .contentShape(Rectangle())
                .background(TwoFingerTracker(
                    onPinch: { phase, scale, focus in
                        switch phase {
                        case .began, .changed:
                            let start = pinchStart ?? (zoom, clamped(pan, scale: base * zoom, in: geo.size))
                            pinchStart = start
                            let z = max(minZoom, min(3, start.zoom * scale))
                            // Keep the point between the fingers under the fingers.
                            let origin = geo.frame(in: .global).origin
                            let f = CGPoint(x: focus.x - origin.x, y: focus.y - origin.y)
                            let k0 = base * start.zoom, k1 = base * z
                            zoom = z
                            pan = CGSize(width: f.x - (f.x - start.pan.width) * k1 / k0,
                                         height: f.y - (f.y - start.pan.height) * k1 / k0)
                        case .ended:
                            pinchStart = nil
                            pan = clamped(pan, scale: base * zoom, in: geo.size)
                        }
                    },
                    onTilt: { phase, dy in onTilt?(phase, dy) },
                    onTwoFingers: {
                        lastTwoFingers = .now
                        if let start = dragStart { pan = start }
                        onTwoFingers?()
                    }))
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { v in
                            guard pinchStart == nil, lastTwoFingers < (dragBegan ?? v.time) else { return }
                            let start = dragStart ?? clamped(pan, scale: base * zoom, in: geo.size)
                            dragStart = start
                            let began = dragBegan ?? v.time
                            dragBegan = began
                            // Hold off a moment before panning, so a quick swipe doesn't jolt the view.
                            guard canPan(scale: base * zoom, in: geo.size), v.time.timeIntervalSince(began) > 0.15 else { return }
                            pan = CGSize(width: start.width + v.translation.width, height: start.height + v.translation.height)
                        }
                        .onEnded { v in
                            guard let start = dragStart else { return }
                            let held = v.time.timeIntervalSince(dragBegan ?? v.time)
                            let wasTwoFingers = lastTwoFingers >= (dragBegan ?? v.time)
                            dragStart = nil
                            dragBegan = nil
                            // A two-finger gesture is a zoom or a tilt, never a swipe or a pan.
                            guard !wasTwoFingers else { return }
                            let k = base * zoom
                            if let onSwipe, hypot(v.translation.width, v.translation.height) > 30,
                               held < 0.3 || !canPan(scale: k, in: geo.size) {
                                func toContent(_ p: CGPoint) -> CGPoint {
                                    CGPoint(x: (p.x - start.width) / k, y: (p.y - start.height) / k)
                                }
                                onSwipe(toContent(v.startLocation), toContent(v.location))
                                withAnimation(.easeOut(duration: 0.2)) { pan = start }
                                return
                            }
                            // A little glide in the direction of the flick.
                            let end = CGSize(width: start.width + v.predictedEndTranslation.width,
                                             height: start.height + v.predictedEndTranslation.height)
                            withAnimation(.easeOut(duration: 0.45)) { pan = clamped(end, scale: base * zoom, in: geo.size) }
                        }
                )
                .overlay(alignment: .bottomTrailing) {
                    if abs(zoom - 1) > 0.01 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) { zoom = 1; pan = .zero }
                        } label: {
                            Label("원래 크기", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(Fonts.body(13, .semibold))
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 14).frame(minHeight: 44)
                                .background(Palette.paper.opacity(0.95), in: Capsule())
                                .overlay(Capsule().stroke(Color(hex: 0xE2D9CC)))
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 24)
                        .padding(.bottom, resetBottom + geo.safeAreaInsets.bottom)
                        .transition(.opacity)
                    }
                }
        }
    }

    private func canPan(scale k: CGFloat, in view: CGSize) -> Bool {
        contentSize.width * k > view.width + 1 || contentSize.height * k > view.height + 1
    }

    /// Keeps the scene covering the screen; a scene smaller than the screen is centered instead.
    private func clamped(_ p: CGSize, scale k: CGFloat, in view: CGSize) -> CGSize {
        func axis(_ v: CGFloat, _ content: CGFloat, _ screen: CGFloat) -> CGFloat {
            content <= screen ? (screen - content) / 2 : min(0, max(screen - content, v))
        }
        return CGSize(width: axis(p.width, contentSize.width * k, view.width),
                      height: axis(p.height, contentSize.height * k, view.height))
    }
}

/// Watches two-finger gestures on the whole window and tells a pinch (fingers moving apart or
/// together: zoom) from a two-finger drag (fingers moving up or down together: 2D↔3D). SwiftUI on
/// iOS 17 can't tell these apart, so this is a small UIKit recognizer that never blocks other touches.
struct TwoFingerTracker: UIViewRepresentable {
    enum Phase { case began, changed, ended }
    var onPinch: (Phase, CGFloat, CGPoint) -> Void
    var onTilt: (Phase, CGFloat) -> Void
    var onTwoFingers: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> HostView {
        let view = HostView()
        view.isUserInteractionEnabled = false
        view.recognizer = context.coordinator.recognizer
        context.coordinator.host = view
        return view
    }

    func updateUIView(_ view: HostView, context: Context) { context.coordinator.parent = self }

    static func dismantleUIView(_ view: HostView, coordinator: Coordinator) { view.detach() }

    /// Hangs the recognizer on the window, so it sees touches that land on the SwiftUI views above.
    final class HostView: UIView {
        var recognizer: UIGestureRecognizer?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let recognizer else { return }
            recognizer.view?.removeGestureRecognizer(recognizer)
            window?.addGestureRecognizer(recognizer)
        }
        func detach() {
            if let recognizer { recognizer.view?.removeGestureRecognizer(recognizer) }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: TwoFingerTracker
        let recognizer = TwoFingerRecognizer()
        weak var host: UIView?

        init(_ parent: TwoFingerTracker) {
            self.parent = parent
            super.init()
            recognizer.addTarget(self, action: #selector(handle(_:)))
            recognizer.delegate = self
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.onTwoFingers = { [weak self] in self?.parent.onTwoFingers() }
        }

        @objc func handle(_ r: TwoFingerRecognizer) {
            let phase: Phase
            switch r.state {
            case .began: phase = .began
            case .changed: phase = .changed
            case .ended, .cancelled: phase = .ended
            default: return
            }
            switch r.mode {
            case .pinch: parent.onPinch(phase, r.scale, r.startCentroid)
            case .tilt: parent.onTilt(phase, r.dy)
            case .undecided: break
            }
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        /// Only touches on this screen itself: not on a sheet or alert shown over it.
        func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let root = host?.window?.rootViewController, root.presentedViewController == nil,
                  let touched = touch.view else { return false }
            return touched.isDescendant(of: root.view)
        }
    }
}

/// Exactly two fingers. Whichever shows first decides the gesture for the rest of it: the gap between
/// the fingers changing (pinch) or both fingers travelling up or down (tilt).
final class TwoFingerRecognizer: UIGestureRecognizer {
    enum Mode { case undecided, pinch, tilt }
    private(set) var mode: Mode = .undecided
    private(set) var scale: CGFloat = 1
    private(set) var dy: CGFloat = 0
    private(set) var startCentroid: CGPoint = .zero
    var onTwoFingers: (() -> Void)?
    private var down: [UITouch] = []
    private var startDistance: CGFloat = 1

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        down.append(contentsOf: touches)
        if down.count == 2 {
            startDistance = max(1, distance())
            startCentroid = centroid()
            mode = .undecided
            onTwoFingers?()
        } else if down.count > 2, state == .possible {
            state = .failed
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard down.count == 2 else { return }
        scale = distance() / startDistance
        dy = centroid().y - startCentroid.y
        if mode == .undecided {
            if abs(scale - 1) > 0.07 { mode = .pinch } else if abs(dy) > 14 { mode = .tilt }
            if mode != .undecided { state = .began }
        } else if state == .began || state == .changed {
            state = .changed
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { lift(touches, cancelled: false) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { lift(touches, cancelled: true) }

    private func lift(_ touches: Set<UITouch>, cancelled: Bool) {
        down.removeAll { touches.contains($0) }
        if state == .began || state == .changed {
            if down.count < 2 { state = cancelled ? .cancelled : .ended }
        } else if down.isEmpty {
            state = .failed
        }
    }

    override func reset() {
        down = []
        mode = .undecided
        scale = 1
        dy = 0
    }

    private func distance() -> CGFloat {
        let a = down[0].location(in: view), b = down[1].location(in: view)
        return hypot(a.x - b.x, a.y - b.y)
    }

    private func centroid() -> CGPoint {
        let a = down[0].location(in: view), b = down[1].location(in: view)
        return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}

/// The ring under a held finger: grows steadily for about two seconds, like a stomp gathering strength.
struct PressGrow: ViewModifier {
    @State private var grown = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(grown ? 3.4 : 0.6)
            .opacity(grown ? 1 : 0.4)
            .onAppear { withAnimation(.linear(duration: 1.7)) { grown = true } }
    }
}

/// A brush stroke along a swipe that fades as the cats scatter.
struct SweepTrail: View {
    let from: CGPoint
    let to: CGPoint
    @State private var gone = false

    var body: some View {
        Path { p in p.move(to: from); p.addLine(to: to) }
            .trim(from: gone ? 1 : 0, to: 1)
            .stroke(Palette.wallTop.opacity(gone ? 0 : 0.35), style: StrokeStyle(lineWidth: 14, lineCap: .round))
            .frame(width: designSize.width, height: max(from.y, to.y) + 10, alignment: .topLeading)
            .onAppear { withAnimation(.easeOut(duration: 0.6)) { gone = true } }
    }
}

/// A box with a cat in it: every few seconds it gives a little shake, as if something turned around inside.
struct Rocking: ViewModifier {
    let active: Bool
    let seed: Int
    @State private var shakes = 0

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: 0.0, trigger: shakes) { view, angle in
                view.rotationEffect(.degrees(angle), anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(-3.5, duration: 0.09)
                    CubicKeyframe(3, duration: 0.11)
                    CubicKeyframe(-2, duration: 0.1)
                    CubicKeyframe(1, duration: 0.1)
                    SpringKeyframe(0, duration: 0.25)
                }
            }
            .task(id: active) {
                guard active else { return }
                // A first wiggle as the cat settles in, then now and then, out of step with other boxes.
                shakes += 1
                var gen = SystemRandomNumberGenerator()
                while !Task.isCancelled {
                    let wait = Double(abs(seed) % 1000) / 1000 + Double.random(in: 1.8...4.2, using: &gen)
                    try? await Task.sleep(for: .seconds(wait))
                    if Task.isCancelled { break }
                    shakes += 1
                }
            }
    }
}

/// The floor ring grows and fades once: slow and small for a call, fast and wide for a shoo.
struct RingPop: ViewModifier {
    let shoo: Bool
    @State private var done = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(done ? (shoo ? 3.2 : 1.8) : 0.4)
            .opacity(done ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: shoo ? 0.5 : 0.9)) { done = true } }
    }
}

struct WarehouseView: View {
    @EnvironmentObject var store: GameStore
    /// Each cat walks from one point to the next; position is computed per frame so taps hit where the cat is drawn.
    private struct Walk { var from: CGPoint; var to: CGPoint; var start: Date; var duration: Double = 3.2; var easeOut = false }
    @State private var walks: [UUID: Walk] = [:]
    /// A ring on the floor where you last tapped: soft for a call, quick and wide for a shoo.
    private struct FloorMark: Identifiable { let id = UUID(); let point: CGPoint; let shoo: Bool }
    @State private var mark: FloorMark?
    /// The current finger on the scene: where and when it went down, and whether it has wandered off.
    private struct Touch { let id = UUID(); let point: CGPoint; let start: Date; var moved = false }
    @State private var touch: Touch?
    /// The ring that grows under a held finger.
    private struct PressMark { let id: UUID; let point: CGPoint }
    @State private var pressMark: PressMark?
    /// The streak a swipe leaves on the floor.
    private struct Trail { let id = UUID(); let from: CGPoint; let to: CGPoint }
    @State private var trail: Trail?
    private static let holdThreshold = 0.3
    @State private var flipped: [UUID: Bool] = [:]
    @State private var toast: FoundCat?
    @State private var toastIsNew = false
    @State private var toastCount = 1
    // Tap reactions: a little hop, a speech bubble, and a pause in its wandering.
    @State private var hopping: Set<UUID> = []
    @State private var bubbles: [UUID: String] = [:]
    @State private var restUntil: [UUID: Date] = [:]
    /// 0 is the flat warehouse (the default), 1 the one seen in depth; two fingers up or down blend between.
    @State private var depthMix: CGFloat = 0
    @State private var tiltStart: CGFloat?
    /// Cats on or in a front box, and which of them have finished getting there.
    @State private var perched: [UUID: BoxPile.PerchKey] = [:]
    @State private var settled: Set<UUID> = []
    @State private var itemToast: BoxItem?
    /// Cats just landing from a jump: squashed for a moment.
    @State private var landing: Set<UUID> = []
    /// After a tap, call or shoo, cats only pause this long before going their own way again.
    private static let settle = 0.4
    /// How often a wandering cat heads for a box instead. SIMCTL_CHILD_NJ_PERCH=1 raises it for testing.
    private static let perchChance: Double = {
        #if DEBUG
        if let v = ProcessInfo.processInfo.environment["NJ_PERCH"], let d = Double(v) { return d }
        #endif
        return 0.14
    }()
    private let reactions = [String(localized: "냐", bundle: .localized), String(localized: "냐아?", bundle: .localized), String(localized: "골골골…", bundle: .localized),
                             String(localized: "꼬리를 살랑", bundle: .localized), "……", String(localized: "하암", bundle: .localized), String(localized: "기지개 쭉", bundle: .localized),
                             String(localized: "킁킁", bundle: .localized), String(localized: "눈을 천천히 깜빡", bundle: .localized)]

    private let walker = Timer.publish(every: 3.4, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // The scene is authored at 390pt wide. Pinch to zoom, drag to look around.
            ZoomPan(contentSize: CGSize(width: designSize.width, height: sceneHeight), resetBottom: 196,
                    onSwipe: { sweep(from: $0, to: $1) },
                    onTilt: { phase, dy in tilt(phase, dy) },
                    onTwoFingers: { touch?.moved = true; pressMark = nil }) {
                ZStack(alignment: .topLeading) {
                    FloorView(top: floorStart, front: frontFeet, height: sceneHeight - floorStart, mix: depthMix)
                        .equatable()
                        .offset(y: floorStart)
                    if let m = mark {
                        let s = catScale(at: m.point.y)
                        Ellipse()
                            .stroke(Palette.wallTop.opacity(0.5), lineWidth: 2)
                            .frame(width: 60 * s, height: 22 * s)
                            .modifier(RingPop(shoo: m.shoo))
                            .offset(x: m.point.x - 30 * s, y: m.point.y - 11 * s)
                            .id(m.id)
                    }
                    if let press = pressMark {
                        let s = catScale(at: press.point.y)
                        Ellipse()
                            .fill(Palette.wallTop.opacity(0.12))
                            .overlay(Ellipse().stroke(Palette.wallTop.opacity(0.55), lineWidth: 2))
                            .frame(width: 60 * s, height: 22 * s)
                            .modifier(PressGrow())
                            .offset(x: press.point.x - 30 * s, y: press.point.y - 11 * s)
                            .id(press.id)
                    }
                    if let t = trail {
                        SweepTrail(from: t.from, to: t.to).id(t.id)
                    }
                    BoxPile(boxes: store.boxes, mix: depthMix, occupied: occupiedBoxes).equatable()
                    // Rare finds, set down in the right-hand corner of the floor.
                    ForEach(Array(cornerItems.enumerated()), id: \.element.id) { i, item in
                        let spot = itemSpot(i)
                        let s = catScale(at: spot.y) * 1.15
                        ZStack(alignment: .bottom) {
                            Ellipse().fill(.black.opacity(0.12)).frame(width: 30 * s, height: 6 * s).offset(y: 2 * s)
                            Image(systemName: item.symbol)
                                .font(.system(size: 22 * s))
                                .foregroundStyle(item.tint)
                                .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
                        }
                        .frame(width: 44 * s, height: 34 * s, alignment: .bottom)
                        .offset(x: spot.x - 22 * s, y: spot.y - 34 * s)
                        .zIndex(Double(spot.y))
                        .accessibilityLabel(item.name)
                    }
                    ForEach(store.cats) { cat in
                        if let species = Catalog.species(cat.speciesID) {
                            // p is where the cat's feet touch the floor; nearer the front, the bigger it's drawn.
                            // The drawing is made once at twice the size and scaled as a whole, so walking never
                            // redraws it and it stays sharp when zoomed in.
                            let p = drawnFeet(of: cat)
                            let s = catScale(at: p.y)
                            // Inside a box, only what's above its rim shows.
                            let rim = insideRim(of: cat).map { Self.catSize - (p.y - $0) } ?? 10_000
                            let hidden = isBuried(cat)
                            CatView(look: species.look, shadow: true)
                                .frame(width: Self.catSize * 2, height: Self.catSize * 2)
                                .scaleEffect(x: ((flipped[cat.id] ?? false) ? -1 : 1) * s / 2 * (landing.contains(cat.id) ? 1.12 : 1),
                                             y: (hopping.contains(cat.id) ? 1.06 : landing.contains(cat.id) ? 0.84 : 1) * s / 2, anchor: .bottom)
                                .frame(width: Self.catSize, height: Self.catSize, alignment: .bottom)
                                .offset(y: hopping.contains(cat.id) ? -18 * s : 0)
                                .mask(alignment: .top) {
                                    Rectangle().frame(width: 300, height: max(0, rim + 300)).offset(y: -300)
                                }
                                .overlay(alignment: .top) {
                                    if let text = bubbles[cat.id] {
                                        Text(text)
                                            .font(Fonts.body(12, .semibold))
                                            .foregroundStyle(Palette.ink)
                                            .fixedSize()
                                            .padding(.horizontal, 10).padding(.vertical, 5)
                                            .background(Palette.paper, in: Capsule())
                                            .overlay(Capsule().stroke(Color(hex: 0xE2D9CC)))
                                            .offset(y: Self.catSize * (1 - s) - 30)
                                            .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
                                    }
                                }
                                .opacity(hidden ? 0 : 1)
                                .accessibilityElement()
                                .accessibilityLabel(hidden ? String(localized: "상자 속 \(species.name)", bundle: .localized) : species.name)
                                .accessibilityAddTraits(.isButton)
                                .accessibilityAction { react(cat) }
                                .offset(x: p.x - Self.catSize / 2, y: p.y - Self.catSize)
                                .zIndex(Double(p.y))  // cats nearer the front stand in front
                                .transition(.opacity)
                        }
                    }
                }
                .allowsHitTesting(false)
                .frame(width: designSize.width, height: sceneHeight, alignment: .topLeading)
                // One tap handler for the whole scene, so a double tap works even on top of a crowd.
                // A cat reacts the moment it's touched; calling to the floor waits until a double tap
                // (a shoo) is ruled out, so a shoo never starts with cats running toward the finger.
                // Tap: pet the cat under the finger, or call them all to that spot — right away.
                // Hold still: stomp; the longer the hold, the farther cats run. Swipes come from ZoomPan.
                .contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 0)
                    .onChanged { touchChanged($0) }
                    .onEnded { touchEnded($0) })
            }
            .background(Palette.ground)
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("창고").font(Fonts.display(32)).foregroundStyle(Palette.ink)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Spacer(minLength: 4)
                        Button { store.screen = .collection } label: {
                            Label("도감 \(store.foundSpecies.count)/\(Catalog.all.count)", systemImage: "book.closed")
                                .font(Fonts.body(14, .semibold))
                                .lineLimit(1).fixedSize()
                                .foregroundStyle(Palette.buttonText)
                                .padding(.horizontal, 16).frame(minHeight: 44)
                                .background(Palette.button, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        Button { store.screen = .log } label: {
                            Image(systemName: "calendar")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Palette.ink)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("운반 일지"))
                        .padding(.trailing, -10)
                        SettingsButton().padding(.trailing, -10)
                    }
                    HStack(spacing: 8) {
                        chip("상자", store.boxes.filter { !$0.open && !$0.isCrushed }.count)
                        chip("고양이", store.cats.count)
                        chip("빈 상자", store.boxes.filter(\.open).count)
                        if store.boxes.contains(where: \.isCrushed) {
                            chip("찌그러진", store.boxes.filter(\.isCrushed).count)
                        }
                    }
                    if !store.boxes.isEmpty { capacityBar }
                }
                .padding(.bottom, 10)
                .background(Palette.ground.padding(.horizontal, -24).ignoresSafeArea(edges: .top))
                if store.boxes.isEmpty && store.cats.isEmpty {
                    Text("아직 창고가 비어 있어요. 첫 상자를 옮겨 보세요.")
                        .font(Fonts.body(14)).foregroundStyle(Palette.inkSoft).padding(.top, 8)
                }
                Spacer()
                if let item = itemToast {
                    ItemFindCard(item: item)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                if let cat = toast, let species = Catalog.species(cat.speciesID) {
                    VStack(alignment: .leading, spacing: 4) {
                        if toastIsNew {
                            Text(toastCount > 1 ? "고양이 \(toastCount)마리가 창고 어딘가에 찾아왔어요." : "창고 어딘가에서 처음 보는 고양이를 발견했어요.")
                                .font(Fonts.body(12)).foregroundStyle(Palette.buttonText.opacity(0.8))
                        }
                        HStack(spacing: 8) {
                            Text(species.name).font(Fonts.body(14, .semibold)).foregroundStyle(Color(hex: 0xF2C35B))
                            GradeChip(grade: species.grade)
                        }
                        Text("처음 발견 \((store.firstFound(species.id)?.date ?? cat.date).monthDay) · 어디서 왔는지는 아무도 몰라요.")
                            .font(Fonts.body(13)).foregroundStyle(Palette.buttonText)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.button, in: RoundedRectangle(cornerRadius: 14))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                PrimaryButton(title: "새 상자 운반하기") { store.screen = .start }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .onReceive(walker) { _ in wander() }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { wander() }
            if let id = store.newCatID, let cat = store.cats.first(where: { $0.id == id }) {
                toastCount = store.newCatCount
                show(cat, isNew: true)
                store.newCatID = nil
            }
        }
        .onAppear { showItem() }
        .onChange(of: store.newItem?.id) { _, _ in showItem() }
        .onChange(of: store.newCatID) { _, id in
            guard let id, let cat = store.cats.first(where: { $0.id == id }) else { return }
            toastCount = store.newCatCount
            show(cat, isNew: true)
            store.newCatID = nil
        }
    }

    // MARK: Capacity

    private var capacityBar: some View {
        // Counts the front row only: that's where new boxes go.
        let level = BoxPile.level(for: store.boxes.count)
        let n = store.boxes.count - level * BoxPile.step, cap = BoxPile.step
        return HStack(spacing: 10) {
            Text(level == 0 ? "창고" : "\(level + 1)번째 줄")
                .font(Fonts.body(12, .semibold)).foregroundStyle(Palette.inkSoft)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: 0xE2D9CC))
                    Capsule().fill(n >= cap ? Palette.risk : Palette.cardboardEdge)
                        .frame(width: g.size.width * CGFloat(n) / CGFloat(cap))
                }
            }
            .frame(height: 6)
            Text(n >= cap ? "꽉 참 · 다음 상자부터 새 줄" : "앞줄 \(n)/\(cap)")
                .font(Fonts.body(12, n >= cap ? .semibold : .regular))
                .foregroundStyle(n >= cap ? Palette.riskText : Palette.muted)
                .fixedSize()
        }
        .frame(minHeight: 24)
    }

    // MARK: Floor depth

    // The cats' floor runs from the front row of boxes toward the viewer. Cats shrink toward the back.
    static let catSize: CGFloat = 68
    private var floorTop: CGFloat { BoxPile.frontBase }
    /// Flat, the floor starts right at the foot of the front row; in depth it runs back under the rows behind.
    private var floorStart: CGFloat {
        let flat = BoxPile.frontBase - 1
        return flat + (BoxPile.floorStart(for: store.boxes.count) - flat) * depthMix
    }
    private var backFeet: CGFloat { floorTop + 10 }
    /// Six cats to a row; the floor gets deeper (and the scene scrolls) only for a crowded warehouse.
    private var floorRows: Int { max(3, Int((Double(store.cats.count) / 6).rounded(.up))) }
    private var frontFeet: CGFloat { backFeet + max(200, CGFloat(floorRows) * 56) }
    private var sceneHeight: CGFloat { max(designSize.height, frontFeet + 120) }
    /// Size at the back of the cats' floor relative to the front.
    private let backScale: CGFloat = 0.62
    /// Cats grow linearly with how far down the floor they stand, which is how a flat floor reads in perspective.
    private func depthScale(at y: CGFloat) -> CGFloat {
        let t = max(0, min(1, (y - backFeet) / (frontFeet - backFeet)))
        return backScale + (1 - backScale) * t
    }
    /// Flat, every cat is the same size; in depth, by how far forward it stands (cats up on boxes count as the back).
    private static let flatScale: CGFloat = 0.78
    private func catScale(at y: CGFloat) -> CGFloat {
        Self.flatScale + (depthScale(at: y) - Self.flatScale) * depthMix
    }

    // MARK: 2D and 3D

    private func tilt(_ phase: TwoFingerTracker.Phase, _ dy: CGFloat) {
        switch phase {
        case .began:
            tiltStart = depthMix
        case .changed:
            // Fingers up lifts the warehouse into depth; down flattens it.
            depthMix = max(0, min(1, (tiltStart ?? depthMix) - dy / 240))
        case .ended:
            tiltStart = nil
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { depthMix = depthMix > 0.5 ? 1 : 0 }
        }
    }

    // MARK: Boxes as perches

    private var perches: [BoxPile.Perch] { BoxPile.perches(store.boxes, mix: depthMix) }

    /// Where a cat's feet go on a perch: on top of the box, or down inside an open one with its head out.
    private func feet(on perch: BoxPile.Perch) -> CGPoint {
        let f = perch.frame
        // A box it disappears into: the spot on the floor just in front of that stack.
        if perch.buried { return CGPoint(x: f.midX, y: backFeet + 6) }
        guard perch.key.inside else { return CGPoint(x: f.midX, y: f.minY + 3) }
        let height = Self.catSize * catScale(at: f.minY)
        return CGPoint(x: f.midX, y: min(f.maxY - 4, f.minY + height * 0.62))
    }

    /// Where the cat is drawn: a settled cat follows its box (which moves between 2D and 3D).
    private func drawnFeet(of cat: FoundCat) -> CGPoint {
        if settled.contains(cat.id), let key = perched[cat.id], let perch = perches.first(where: { $0.key == key }) {
            return feet(on: perch)
        }
        return walks[cat.id]?.to ?? home(for: cat)
    }

    private func perch(of cat: FoundCat) -> BoxPile.Perch? {
        guard settled.contains(cat.id), let key = perched[cat.id] else { return nil }
        return perches.first { $0.key == key }
    }

    /// Gone into a box lower in a stack: not drawn at all until it comes out.
    private func isBuried(_ cat: FoundCat) -> Bool { perch(of: cat)?.buried ?? false }

    private var occupiedBoxes: Set<UUID> {
        Set(store.cats.compactMap { cat in perch(of: cat).flatMap { $0.key.inside ? $0.key.box : nil } })
    }

    /// Off the top of a box: crouch, a small spring up, a fall to the floor in front with a squash on
    /// landing, then on to wherever it was going.
    private func jumpDown(_ cat: FoundCat, from p: BoxPile.Perch, then target: CGPoint, duration: Double, rest: Double) {
        let id = cat.id
        let start = feet(on: p)
        let side: CGFloat = target.x < p.frame.midX ? -1 : 1
        let peak = CGPoint(x: start.x + side * 10, y: start.y - 16)
        let floor = clampToFloor(CGPoint(x: p.frame.midX + side * (p.frame.width * 0.45), y: backFeet + 14))
        perched[id] = nil
        settled.remove(id)
        flipped[id] = side < 0
        restUntil[id] = Date.now.addingTimeInterval(0.8 + duration + rest)
        walks[id] = Walk(from: start, to: start, start: .now)
        withAnimation(.easeOut(duration: 0.16)) {
            walks[id] = Walk(from: start, to: peak, start: .now, duration: 0.16, easeOut: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            // Falling speeds up, so ease in.
            withAnimation(.easeIn(duration: 0.32)) {
                walks[id] = Walk(from: peak, to: floor, start: .now, duration: 0.32)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) { _ = landing.insert(id) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) { _ = landing.remove(id) }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            guard perched[id] == nil, let cat = store.cats.first(where: { $0.id == id }) else { return }
            if hypot(target.x - floor.x, target.y - floor.y) > 8 {
                send(cat, to: target, duration: duration, restFor: rest, now: .now)
            }
        }
    }

    /// Tapping a box with a cat in it: the box jolts and the cat springs out onto the floor in front.
    private func popOut(at point: CGPoint) -> Bool {
        guard let cat = store.cats.first(where: { cat in
            guard let p = perch(of: cat), p.key.inside else { return false }
            return p.frame.insetBy(dx: -6, dy: -6).contains(point)
        }), let p = perch(of: cat) else { return false }
        let now = Date.now
        let start = feet(on: p)
        let landing = clampToFloor(CGPoint(x: p.frame.midX + CGFloat.random(in: -40...40), y: backFeet + CGFloat.random(in: 30...90)))
        perched[cat.id] = nil
        settled.remove(cat.id)
        flipped[cat.id] = landing.x < start.x
        // Out over the top (or, from a hidden box, a hop out of its front): up, then down to the floor.
        let top = p.buried ? CGPoint(x: start.x, y: start.y - 34) : CGPoint(x: start.x, y: p.frame.minY - 6)
        walks[cat.id] = Walk(from: start, to: start, start: now)
        withAnimation(.easeOut(duration: 0.18)) {
            walks[cat.id] = Walk(from: start, to: top, start: now, duration: 0.18, easeOut: true)
        }
        restUntil[cat.id] = now.addingTimeInterval(0.8 + Self.settle)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.7)) {
                walks[cat.id] = Walk(from: top, to: landing, start: .now, duration: 0.45, easeOut: true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) { _ = self.landing.insert(cat.id) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) { _ = self.landing.remove(cat.id) }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { react(cat, line: [String(localized: "냐!", bundle: .localized), String(localized: "깜짝이야", bundle: .localized), String(localized: "들켰다", bundle: .localized), String(localized: "냐아앙", bundle: .localized)].randomElement()!) }
        }
        return true
    }

    private func insideRim(of cat: FoundCat) -> CGFloat? {
        guard settled.contains(cat.id), let key = perched[cat.id], key.inside,
              let perch = perches.first(where: { $0.key == key }) else { return nil }
        return perch.frame.minY + 2
    }

    /// Hop up onto a free front box, or into it if it's an open one. Inside boxes, it climbs to the rim
    /// first and then drops in, so it's never drawn over the front of the box on the way.
    private func climb(_ cat: FoundCat, onto perch: BoxPile.Perch, now: Date) {
        // Into a hidden box: walk across the floor to the front of the stack and fade away there.
        let rimPoint = perch.buried ? feet(on: perch) : CGPoint(x: perch.frame.midX, y: perch.frame.minY + 3)
        // A cat inside a box tends to stay a while; a cat on top moves on sooner.
        send(cat, to: rimPoint, duration: perch.buried ? 1.8 : 1.3, restFor: perch.key.inside ? Double.random(in: 10...25) : Double.random(in: 5...12), now: now)
        perched[cat.id] = perch.key
        let id = cat.id
        DispatchQueue.main.asyncAfter(deadline: .now() + (perch.buried ? 1.8 : 1.3)) {
            guard perched[id] == perch.key else { return }
            withAnimation(.easeIn(duration: perch.buried ? 0.7 : perch.key.inside ? 0.25 : 0.1)) { _ = settled.insert(id) }
        }
    }

    /// Each kind of item found, in the order first found.
    private var cornerItems: [BoxItem] {
        var seen: Set<String> = []
        return store.items.compactMap { f in seen.insert(f.itemID).inserted ? BoxItem.item(f.itemID) : nil }
    }

    /// A small heap against the right wall: two staggered rows, filling toward the middle.
    private func itemSpot(_ i: Int) -> CGPoint {
        let row = i % 2, col = i / 2
        return CGPoint(x: 362 - CGFloat(col) * 30 - CGFloat(row) * 15, y: backFeet + 10 + CGFloat(row) * 16)
    }

    private func item(at p: CGPoint) -> BoxItem? {
        cornerItems.enumerated().first { i, _ in
            let spot = itemSpot(i)
            return CGRect(x: spot.x - 22, y: spot.y - 34, width: 44, height: 40).contains(p)
        }?.element
    }

    private func showItem() {
        guard let found = store.newItem, let item = BoxItem.item(found.itemID) else { return }
        store.newItem = nil
        withAnimation { itemToast = item }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if itemToast?.id == item.id { withAnimation { itemToast = nil } }
        }
    }

    private func chip(_ label: LocalizedStringKey, _ n: Int) -> some View {
        (Text(label) + Text(" ") + Text("\(n)").fontWeight(.semibold))
            .font(Fonts.body(13)).foregroundStyle(Palette.ink)
            .lineLimit(1).minimumScaleFactor(0.75)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Palette.paper, in: Capsule())
            .overlay(Capsule().stroke(Color(hex: 0xE2D9CC)))
    }

    private func home(for cat: FoundCat) -> CGPoint {
        let h = cat.id.uuidString.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFFFF }
        let index = store.cats.firstIndex { $0.id == cat.id } ?? 0
        // Spread cats over the rows so a big warehouse starts evenly filled.
        let row = CGFloat(index / 6 % floorRows), col = CGFloat(index % 6)
        let rowDepth = (frontFeet - backFeet) / CGFloat(floorRows)
        return CGPoint(x: 44 + col * 60 + CGFloat(h % 24) - 12,
                       y: backFeet + (row + 0.5) * rowDepth + CGFloat((h / 7) % 16) - 8)
    }

    private func position(of cat: FoundCat, at date: Date) -> CGPoint {
        if settled.contains(cat.id), perched[cat.id] != nil { return drawnFeet(of: cat) }
        guard let w = walks[cat.id] else { return home(for: cat) }
        let t = CGFloat(max(0, min(1, date.timeIntervalSince(w.start) / w.duration)))
        // Follow the same curve the walk is drawn with, so taps land on a moving cat.
        let q = w.easeOut ? 1 - (1 - t) * (1 - t) : t
        return CGPoint(x: w.from.x + (w.to.x - w.from.x) * q, y: w.from.y + (w.to.y - w.from.y) * q)
    }

    private func wander() {
        let now = Date.now
        // The render server animates the walk; the same straight line is recomputed for taps.
        let free = perches.filter { p in !perched.values.contains(p.key) }
        var taken: Set<BoxPile.PerchKey> = []
        for cat in store.cats where Double.random(in: 0..<1) < 0.35 {
            if let rest = restUntil[cat.id], rest > now { continue }
            if let w = walks[cat.id], now.timeIntervalSince(w.start) < w.duration { continue }
            // Now and then a cat goes up onto a box, or into an open one.
            if perched[cat.id] == nil, Double.random(in: 0..<1) < Self.perchChance,
               let perch = free.filter({ !taken.contains($0.key) }).randomElement() {
                taken.insert(perch.key)
                climb(cat, onto: perch, now: now)
                continue
            }
            let next = CGPoint(x: CGFloat.random(in: 40...350), y: CGFloat.random(in: backFeet...frontFeet))
            if perched[cat.id] != nil {
                // Hops down and wanders off.
                send(cat, to: next, duration: 1.2, restFor: 0, now: now)
                continue
            }
            let here = position(of: cat, at: now)
            flipped[cat.id] = next.x < here.x  // turn instantly, then walk
            withAnimation(.linear(duration: 3.2)) {
                walks[cat.id] = Walk(from: here, to: next, start: now)
            }
        }
    }

    // MARK: Calling and shooing

    private func touchChanged(_ v: DragGesture.Value) {
        // A new finger has a new start point; this also recovers if a cancelled touch never ended.
        if touch == nil || touch?.point != v.startLocation {
            let t = Touch(point: v.startLocation, start: v.time)
            touch = t
            pressMark = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.holdThreshold) {
                guard let now = touch, now.id == t.id, !now.moved else { return }
                pressMark = PressMark(id: t.id, point: floorPoint(t.point))
            }
        }
        if hypot(v.translation.width, v.translation.height) > 10, touch?.moved == false {
            touch?.moved = true
            pressMark = nil
        }
    }

    private func touchEnded(_ v: DragGesture.Value) {
        guard let t = touch, t.point == v.startLocation else { return }
        touch = nil
        pressMark = nil
        guard !t.moved, hypot(v.translation.width, v.translation.height) <= 10 else { return }
        let held = v.time.timeIntervalSince(t.start)
        if held >= Self.holdThreshold {
            // Full strength after about two seconds of holding.
            shoo(from: floorPoint(t.point), strength: min(1, (held - Self.holdThreshold) / 1.7))
        } else if let cat = cat(at: t.point) {
            react(cat)
        } else if popOut(at: t.point) {
            // handled
        } else if let item = item(at: t.point) {
            withAnimation { itemToast = item }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if itemToast?.id == item.id { withAnimation { itemToast = nil } }
            }
        } else if t.point.y >= floorTop {
            call(to: floorPoint(t.point))
        }
    }

    /// The front-most cat drawn under a point, with a 44pt minimum target for the small ones at the back.
    private func cat(at p: CGPoint) -> FoundCat? {
        let now = Date.now
        return store.cats
            .filter { cat in !(perch(of: cat)?.key.inside ?? false) }
            .map { ($0, position(of: $0, at: now)) }
            .filter { _, feet in
                let size = max(44, Self.catSize * catScale(at: feet.y))
                return CGRect(x: feet.x - size / 2, y: feet.y - size, width: size, height: size).contains(p)
            }
            .max { $0.1.y < $1.1.y }?.0
    }

    /// A tap on the floor, in scene coordinates, kept inside where cats can walk.
    private func floorPoint(_ p: CGPoint) -> CGPoint {
        CGPoint(x: max(40, min(350, p.x)), y: max(backFeet, min(frontFeet, p.y)))
    }

    private func clampToFloor(_ p: CGPoint) -> CGPoint {
        CGPoint(x: max(30, min(360, p.x)), y: max(backFeet, min(frontFeet, p.y)))
    }

    private func send(_ cat: FoundCat, to target: CGPoint, duration: Double, restFor rest: Double, now: Date) {
        // Up on a box (or peeking out of one): it jumps down first, then goes on its way.
        if let p = perch(of: cat), !p.buried {
            jumpDown(cat, from: p, then: target, duration: duration, rest: rest)
            return
        }
        let here = position(of: cat, at: now)
        // Anywhere it's sent, it leaves the box it was on.
        perched[cat.id] = nil
        if perch(of: cat)?.buried ?? false {
            // Out of a hidden box: fades back in where it went in.
            _ = withAnimation(.easeOut(duration: 0.35)) { settled.remove(cat.id) }
        }
        settled.remove(cat.id)
        flipped[cat.id] = target.x < here.x
        restUntil[cat.id] = now.addingTimeInterval(duration + rest)
        withAnimation(.easeOut(duration: duration)) {
            walks[cat.id] = Walk(from: here, to: target, start: now, duration: duration, easeOut: true)
        }
    }

    /// Single tap: every cat trots over and settles in a loose cluster around the spot, nearest cats closest.
    private func call(to point: CGPoint) {
        let now = Date.now
        withAnimation(.easeOut(duration: 0.2)) { mark = FloorMark(point: point, shoo: false) }
        let byDistance = store.cats.sorted {
            hypot(position(of: $0, at: now).x - point.x, position(of: $0, at: now).y - point.y)
                < hypot(position(of: $1, at: now).x - point.x, position(of: $1, at: now).y - point.y)
        }
        let s = catScale(at: point.y)
        for (i, cat) in byDistance.enumerated() {
            // Sunflower spiral: even spacing without a visible grid. Depth is squashed, as the floor is seen at an angle.
            let angle = Double(i) * 2.39996, r = 30 * s * CGFloat(Double(i).squareRoot())
            let target = clampToFloor(CGPoint(x: point.x + r * CGFloat(cos(angle)), y: point.y + r * 0.45 * CGFloat(sin(angle))))
            send(cat, to: target, duration: 2.4 + Double(i) * 0.06, restFor: Self.settle, now: now)
        }
    }

    /// Double tap: cats nearby dash away from the spot; the farther a cat already is, the less it bothers.
    /// Stomp: cats around the spot run off; a longer hold (strength 0…1) reaches farther and pushes harder.
    private func shoo(from point: CGPoint, strength: Double) {
        let now = Date.now
        let reach = 140 + 180 * CGFloat(strength)
        withAnimation(.easeOut(duration: 0.2)) { mark = FloorMark(point: point, shoo: true) }
        for cat in store.cats {
            let here = position(of: cat, at: now)
            var dx = here.x - point.x, dy = (here.y - point.y) / 0.45
            var dist = hypot(dx, dy)
            if dist < 1 { let a = Double.random(in: 0..<(2 * .pi)); dx = CGFloat(cos(a)); dy = CGFloat(sin(a)); dist = 1 }
            guard dist < reach + 60 else { continue }  // well out of range: doesn't notice
            let push = max(30, reach - dist) * (0.8 + 0.5 * CGFloat(strength))
            let target = clampToFloor(CGPoint(x: here.x + dx / dist * push, y: here.y + dy / dist * push * 0.45))
            send(cat, to: target, duration: 1.1, restFor: Self.settle, now: now)
        }
    }

    /// Swipe: cats near the stroke scatter the way it went, and a little away from the line.
    private func sweep(from a: CGPoint, to b: CGPoint) {
        let now = Date.now
        let dx = b.x - a.x, dy = b.y - a.y, len = hypot(dx, dy)
        guard len > 20 else { return }
        let ux = dx / len, uy = dy / len
        withAnimation(.easeOut(duration: 0.15)) { trail = Trail(from: a, to: b) }
        let reach: CGFloat = 110
        for cat in store.cats {
            let here = position(of: cat, at: now)
            // Closest point on the stroke; depth counts double, as the floor is seen at an angle.
            let t = max(0, min(len, (here.x - a.x) * ux + (here.y - a.y) * uy))
            let near = CGPoint(x: a.x + ux * t, y: a.y + uy * t)
            var sx = here.x - near.x, sy = (here.y - near.y) / 0.5
            let dist = hypot(sx, sy)
            guard dist < reach else { continue }
            if dist > 0.5 { sx /= dist; sy /= dist } else { sx = -uy; sy = ux }
            let push = 90 + 170 * (1 - dist / reach)
            let target = clampToFloor(CGPoint(x: here.x + (ux * 0.85 + sx * 0.45) * push,
                                              y: here.y + (uy * 0.85 + sy * 0.45) * push * 0.5))
            send(cat, to: target, duration: 0.9, restFor: Self.settle, now: now)
        }
    }

    /// Tapped cat stops where it is, hops, says something, then stays put for a few seconds.
    private func react(_ cat: FoundCat, line custom: String? = nil) {
        let now = Date.now
        let here = position(of: cat, at: now)
        if perched[cat.id] == nil { walks[cat.id] = Walk(from: here, to: here, start: now) }
        restUntil[cat.id] = now.addingTimeInterval(Self.settle + 0.6)
        let line = custom ?? reactions.randomElement() ?? "냐"
        withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) {
            hopping.insert(cat.id)
            bubbles[cat.id] = line
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { _ = hopping.remove(cat.id) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if bubbles[cat.id] == line { withAnimation(.easeOut(duration: 0.25)) { bubbles[cat.id] = nil } }
        }
        show(cat, isNew: false)
    }

    private func show(_ cat: FoundCat, isNew: Bool) {
        withAnimation { toast = cat; toastIsNew = isNew }
        let id = cat.id
        DispatchQueue.main.asyncAfter(deadline: .now() + (isNew ? 4 : 3.2)) {
            if toast?.id == id { withAnimation { toast = nil } }
        }
    }
}

// MARK: Collection

struct CollectionView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        let found = store.foundSpecies
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button { store.screen = .warehouse } label: {
                        Label("창고", systemImage: "chevron.left").font(Fonts.body(14)).foregroundStyle(Palette.ink)
                            .frame(minHeight: 44)
                    }
                    Spacer()
                    (Text("\(found.count)").fontWeight(.semibold).foregroundStyle(Palette.ink) + Text(" / \(Catalog.all.count) 발견"))
                        .font(Fonts.body(13)).foregroundStyle(Palette.muted)
                }
                Text("도감").font(Fonts.display(30)).foregroundStyle(Palette.ink)

                ForEach(Grade.allCases) { grade in
                    let list = Catalog.all.filter { $0.grade == grade }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            GradeChip(grade: grade)
                            Text("\(list.filter { found.contains($0.id) }.count)/\(list.count)")
                                .font(Fonts.body(12)).foregroundStyle(Palette.muted)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10) {
                            ForEach(list) { species in
                                let has = found.contains(species.id)
                                VStack(spacing: 4) {
                                    CatView(look: has ? species.look : species.look.silhouette)
                                        .frame(width: 54, height: 54)
                                        .frame(maxWidth: .infinity, minHeight: 64)
                                        .background(has ? Color(hex: 0xE9DFD0) : Color(hex: 0xE2D9CC), in: RoundedRectangle(cornerRadius: 14))
                                    Text(has ? species.name : "???")
                                        .font(Fonts.body(11))
                                        .foregroundStyle(has ? Palette.ink : Color(hex: 0x8A7E70))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(has ? "\(species.name), \(grade.label)" : String(localized: "아직 못 만난 \(grade.label) 고양이", bundle: .localized))
                            }
                        }
                    }
                }

                // Things found in boxes: nothing at all until the first turns up, then just the finds
                // themselves, in the order found, with no heading or count to hint at more.
                let found: [BoxItem] = {
                    var seen: Set<String> = []
                    return store.items.compactMap { f in seen.insert(f.itemID).inserted ? BoxItem.item(f.itemID) : nil }
                }()
                if !found.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10) {
                        ForEach(found) { item in
                            VStack(spacing: 4) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 24))
                                    .foregroundStyle(item.tint)
                                    .frame(maxWidth: .infinity, minHeight: 64)
                                    .background(Color(hex: 0xE9DFD0), in: RoundedRectangle(cornerRadius: 14))
                                Text(item.name)
                                    .font(Fonts.body(11))
                                    .foregroundStyle(Palette.ink)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.top, 6)
                }

                Text("한 번도 열지 않고 도착한 상자에서는 귀한 고양이를 만나기 쉬워요. 전설 고양이는 저마다 나오는 조건이 있어요.")
                    .font(Fonts.body(12)).foregroundStyle(Palette.muted)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Palette.ground.ignoresSafeArea())
    }
}
