import SwiftUI

@main
struct NyangJahakApp: App {
    @StateObject private var store = GameStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppLanguage.storageKey) private var language: AppLanguage = .system

    init() { AppLanguage.current.apply() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(store.motion)
                // A new language rebuilds every screen, so text worked out once (like the cats' lines) is redone too.
                .environment(\.locale, language.locale)
                .id(language)
                .onChange(of: language) { _, lang in lang.apply() }
                .onChange(of: scenePhase) { _, phase in store.scenePhaseChanged(phase) }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        Group {
            switch store.screen {
            case .start: StartView()
            case .pack: PackView()
            case .transport: TransportView()
            case .open: OpenView()
            case .arrive: ArriveView()
            case .warehouse: WarehouseView()
            case .collection: CollectionView()
            case .log: CarryLogView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.screen)
        .preferredColorScheme(.light)
        #if DEBUG
        .overlay(alignment: .top) { if !screenshotMode { DebugButton() } }
        #endif
    }
}

/// The app's own settings: for now, just the language.
struct SettingsButton: View {
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            Image(systemName: "globe")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Palette.ink)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("언어"))
        .sheet(isPresented: $open) { SettingsView().presentationDetents([.medium]) }
    }
}

struct SettingsView: View {
    @AppStorage(AppLanguage.storageKey) private var language: AppLanguage = .system
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AppLanguage.allCases) { lang in
                        Button {
                            // Close first: the switch rebuilds the screen underneath.
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { language = lang }
                        } label: {
                            HStack {
                                Text(lang.title).foregroundStyle(Palette.ink)
                                Spacer()
                                if lang == language { Image(systemName: "checkmark").foregroundStyle(Palette.ink) }
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("언어")
                } footer: {
                    Text("바꾸면 바로 적용돼요. 홈 화면의 앱 이름은 기기 언어를 따라요.")
                }
            }
            .navigationTitle(Text("설정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } }
            }
        }
    }
}

#if DEBUG
/// On-device testing aid: a small pill at the top that opens live sensor values and the event log.
struct DebugButton: View {
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            Text("DEBUG")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 10).frame(minHeight: 22)
                .background(Color.black.opacity(0.55), in: Capsule())
                .frame(minWidth: 64, minHeight: 44)
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
        .sheet(isPresented: $open) { DebugPanel().presentationDetents([.medium, .large]) }
    }
}

struct DebugPanel: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var motion: MotionMonitor
    @State private var confirmReset = false

    var body: some View {
        List {
            Section("센서") {
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    VStack(alignment: .leading, spacing: 6) {
                        row("중력 z", String(format: "%+.2f", motion.gravityZ))
                        row("화면 방향", motion.screenDown ? "아래 (z > 0.8, 해제 z < 0.6)" : "아래 아님")
                        row("근접 센서", motion.proximityAvailable ? (motion.proximityCovered ? "가려짐" : "열림") : "없음")
                        row("엎음 판정", motion.faceDown ? "엎어짐" : "들려 있음")
                        row("동작 센서", motion.sensorsAvailable ? "사용 가능" : "없음 (시뮬레이터)")
                    }
                }
            }
            Section("현재 상자") {
                if let t = store.transport {
                    row("화면", "\(store.screen)")
                    row("운반", "\(Int(t.carried))초 / \(Int(t.duration))초")
                    row("열어본 횟수", "\(t.opens)")
                    row("상태", t.hasPresence ? "기척 있음" : (t.emptyReason == .broken ? "병 깨짐" : "빠져나감"))
                    row("열어둔 시간", t.openedAt == nil ? "닫힘" : "\(Int(t.openSeconds))초 · 판정 \(t.leaveRolls ?? 0)회 · 누적 \(Int(store.leaveRisk(openSeconds: t.openSeconds) * 100))%")
                } else {
                    Text("운반 중인 상자 없음").foregroundStyle(.secondary)
                }
                Toggle("빠른 테스트 (3초마다 50%로 빠져나감)", isOn: $store.fastTest)
                if store.transport != nil {
                    Button("운반 시간 30분 앞으로") { store.debugAdvance(minutes: 30) }
                }
                Button("창고에 고양이 8마리 추가") { store.debugAddCats(8) }
                Button("창고에 상자 20개 추가") { store.debugAddBoxes(20) }
                Button("상자 속 물건 하나 발견하기") { store.debugFindItem() }
            }
            Section {
                Button("전체 초기화", role: .destructive) { confirmReset = true }
            } footer: {
                Text("처음 설치한 상태로 돌아가요. 되돌릴 수 없어요.")
            }
            Section("최근 이벤트") {
                if store.eventLog.isEmpty { Text("아직 없음").foregroundStyle(.secondary) }
                ForEach(store.eventLog, id: \.self) { Text($0).font(.system(size: 13, design: .monospaced)) }
            }
        }
        .alert("전체 초기화할까요?", isPresented: $confirmReset) {
            Button("모두 지우기", role: .destructive) { store.debugReset() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("창고의 상자와 고양이, 도감, 운반 중인 상자를 모두 지워요.")
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(.secondary); Spacer(); Text(v).monospacedDigit() }
            .font(.system(size: 14))
    }
}
#endif

// MARK: Shared pieces

struct PrimaryButton: View {
    let title: LocalizedStringKey
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Fonts.body(16, .semibold))
                .foregroundStyle(Palette.buttonText)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Palette.button, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct SecondaryButton: View {
    let title: LocalizedStringKey
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Fonts.body(15, .medium))
                .foregroundStyle(Palette.button)
                .frame(maxWidth: .infinity, minHeight: 50)
                .overlay(Capsule().stroke(Color(hex: 0x6E5034), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct GradeChip: View {
    let grade: Grade

    var body: some View {
        Text(grade.label)
            .font(Fonts.body(11, .semibold))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(grade.chip, in: Capsule())
    }
}

/// Launched with NJ_SCREENSHOTS=1 (simulator, for App Store screenshots): test-only controls are hidden.
let screenshotMode = ProcessInfo.processInfo.environment["NJ_SCREENSHOTS"] == "1"

/// The simulator has no motion sensors; this toggle stands in for flipping the phone.
struct SimulatorFlipToggle: View {
    @EnvironmentObject var motion: MotionMonitor

    var body: some View {
        if !motion.sensorsAvailable && !screenshotMode {
            Toggle(isOn: $motion.simulatedFaceDown) {
                Text("폰 엎어두기 (시뮬레이터)")
                    .font(Fonts.body(13, .medium))
                    .foregroundStyle(Palette.inkSoft)
            }
            .tint(Palette.button)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Palette.paper.opacity(0.9), in: Capsule())
        }
    }
}

func clock(_ seconds: TimeInterval) -> String {
    let s = Int(seconds.rounded(.up))
    // Hours appear once a carry runs past an hour (arrival-time boxes can run 12).
    if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) }
    return String(format: "%02d:%02d", s / 60, s % 60)
}

func shortClock(_ seconds: TimeInterval) -> String {
    let s = Int(seconds)
    return "\(s / 60):" + String(format: "%02d", s % 60)
}

extension Date {
    var monthDay: String {
        formatted(.dateTime.month(.wide).day().locale(AppLanguage.current.locale))
    }
}
