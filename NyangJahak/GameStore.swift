import SwiftUI
import CoreMotion
import UIKit

enum Screen: Equatable {
    case start
    case pack
    case transport
    case open
    case arrive
    case warehouse
    case collection
    case log
}

/// Watches whether the phone lies face down *on something*.
/// Gravity alone is not enough: a phone held screen-down above your face in bed points the same way.
/// So the screen must also be covering the proximity sensor (screen pressed against a surface).
final class MotionMonitor: ObservableObject {
    @Published private(set) var faceDown = false
    /// Lets the simulator, which has no motion sensors, pretend the phone is face down.
    @Published var simulatedFaceDown = false {
        didSet { if !manager.isDeviceMotionAvailable { faceDown = simulatedFaceDown } }
    }

    /// Latest gravity z (+1 = screen facing down). Not published; the debug panel polls it.
    private(set) var gravityZ: Double = 0
    /// Whether gravity says "screen facing down", with hysteresis.
    private(set) var screenDown = false
    /// Whether something is right against the screen (proximity sensor covered).
    private(set) var proximityCovered = false
    /// False on devices without a proximity sensor; then gravity alone decides.
    private(set) var proximityAvailable = true

    private let manager = CMMotionManager()
    private var proximityObserver: NSObjectProtocol?

    var sensorsAvailable: Bool { manager.isDeviceMotionAvailable }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 0.2
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let g = motion?.gravity else { return }
            self.gravityZ = g.z
            // Screen facing the ground: gravity points out of the screen (z ≈ +1).
            self.screenDown = self.screenDown ? g.z > 0.6 : g.z > 0.8
            self.update()
        }
        proximityObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.proximityStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.proximityCovered = UIDevice.current.proximityState
            self?.update()
        }
    }

    /// The proximity sensor only reports while monitoring is on, and turning it on also lets iOS
    /// blank the screen when covered, so it is enabled only while a box is in play.
    func setProximityMonitoring(_ on: Bool) {
        let device = UIDevice.current
        device.isProximityMonitoringEnabled = on
        if on {
            // Setting it on a device without the sensor silently leaves it off.
            proximityAvailable = device.isProximityMonitoringEnabled
            proximityCovered = device.proximityState
        } else {
            proximityCovered = false
        }
        update()
    }

    private func update() {
        guard manager.isDeviceMotionAvailable else { return }
        let down = screenDown && (proximityAvailable ? proximityCovered : true)
        if down != faceDown { faceDown = down }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        if let proximityObserver { NotificationCenter.default.removeObserver(proximityObserver) }
    }
}

final class GameStore: ObservableObject {
    // Tunables (draft values from the plan).
    static let baseBreakChance = 0.2
    static let breakChancePerOpen = 0.05

    @Published var screen: Screen = .start {
        didSet {
            // While a box is in play, use the proximity sensor to tell "face down on something"
            // from "held screen-down in the air"; it also blanks the screen when covered.
            motion.setProximityMonitoring(screen == .transport || screen == .open)
        }
    }
    /// Debug: shortens the time before the presence slips out, for on-device testing.
    @Published var fastTest = false
    /// While the box is open, every `leaveInterval` seconds the presence slips out with `leaveChance`.
    var leaveInterval: TimeInterval { fastTest ? 3 : 10 }
    var leaveChance: Double { fastTest ? 0.5 : 0.1 }
    /// Chance the presence has slipped out by now, for the risk bar.
    func leaveRisk(openSeconds: TimeInterval) -> Double {
        1 - pow(1 - leaveChance, (openSeconds / leaveInterval).rounded(.down))
    }
    /// Debug: recent events with timestamps, newest first.
    @Published private(set) var eventLog: [String] = []
    @Published var transport: Transport? { didSet { live = transport } }
    /// Working copy updated every tick; only published when something visible changes.
    private var live: Transport?
    @Published private(set) var boxes: [StoredBox] = []
    @Published private(set) var cats: [FoundCat] = []
    @Published private(set) var unopenedStreak = 0
    /// After abandoning, no new box until the abandoned one would have arrived.
    @Published private(set) var blockedUntil: Date?
    /// Carrying an empty box all the way earns better odds on the next box that brings cats.
    @Published private(set) var bonusNext = false
    static let bonusMultiplier = 1.5

    func isBlocked(at date: Date = .now) -> Bool { (blockedUntil ?? .distantPast) > date }
    /// Set when the presence slipped out while you were watching, so the open screen can play it.
    @Published var presenceJustLeft = false
    /// The cat that appeared from the last stacked box, shown with a toast in the warehouse.
    @Published var newCatID: UUID?
    /// How many cats came with the last stacked box.
    @Published var newCatCount = 0
    /// Things other than cats found in boxes; very rare.
    @Published private(set) var items: [FoundItem] = []
    /// The item that came with the last stacked box, if any, for the arrival screen and a warehouse toast.
    @Published var newItem: FoundItem?
    /// What the screen looked like the moment the phone went into the box, so the pack screen can shrink it in.
    var packSnapshot: UIImage?
    static let itemChance = 0.03
    /// "Until open" boxes kept shut two hours or more hide things more often.
    static let longItemChance = 0.08
    /// The longest an "until open" box can go before it opens itself.
    static let untilOpenCap: TimeInterval = 12 * 3600
    /// Picking up a face-down "until open" box gives this long to put it back before it counts as opened.
    static let liftGrace: TimeInterval = 5
    /// When the phone was picked up during an "until open" carry, while the grace runs.
    @Published private(set) var liftedAt: Date?

    /// One cat per 25 minutes carried, at least 1.
    static func catCount(minutes: Double) -> Int { max(1, Int(minutes / 25)) }

    let motion = MotionMonitor()
    private var armed = false
    private var timer: Timer?
    private var lastFaceDown = false
    private var motionSink: Any?

    private let saveKey = "nyang.save.v1"

    init() {
        load()
        if let t = transport, t.arrived, t.openedAt == nil {
            // Closed on the arrival screen, before the box was put down: pick up from there.
            screen = .arrive
        } else if let t = transport {
            // The app was closed while carrying: treat it as an opened box (plan: forced quit = opened).
            screen = .open
            if t.openedAt == nil { openBox(at: t.lastTick, countOpen: true) }
        } else if !cats.isEmpty || !boxes.isEmpty {
            screen = .warehouse
        }
        log("앱 시작" + (transport != nil ? " · 운반 중이던 상자를 연 것으로 처리" : ""))
        motion.start()
        motion.setProximityMonitoring(screen == .transport || screen == .open)
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
    }

    // MARK: Flow

    func beginPacking(mode: TransportMode, minutes: Double) {
        transport = Transport(mode: mode, duration: mode == .untilOpen ? Self.untilOpenCap : minutes * 60,
                              arrivesAt: mode == .byArrival ? Date.now.addingTimeInterval(minutes * 60) : nil)
        armed = false
        screen = .pack
        save()
    }

    func startCarrying() {
        guard transport != nil else { return }
        transport?.lastTick = .now
        armed = false
        liftedAt = nil
        screen = .transport
        UIApplication.shared.isIdleTimerDisabled = true
        log("출발")
        save()
    }

    /// Giving up: the box is stacked crushed, the streak and bonus are lost,
    /// and no new box can start until the original arrival time.
    func abandon() {
        if let t = live ?? transport {
            boxes.append(StoredBox(open: false, date: .now, crushed: true, minutes: t.carried / 60, mode: t.mode))
            blockedUntil = Date.now.addingTimeInterval(t.remaining)
            unopenedStreak = 0
            bonusNext = false
            log("운반 그만둠 · 찌그러진 상자 · \(Int(t.remaining))초 동안 새 상자 불가")
        }
        transport = nil
        UIApplication.shared.isIdleTimerDisabled = false
        screen = boxes.isEmpty ? .start : .warehouse
        save()
    }

    /// Lifting the phone, leaving the app, or reopening after a forced quit all open the box.
    func openBox(at date: Date = .now, countOpen: Bool = true) {
        guard var t = live ?? transport, t.openedAt == nil else { return }
        if t.mode == .untilOpen { observe(t, at: date); return }
        if countOpen { t.opens += 1 }
        if t.hasPresence {
            let chance = min(0.6, Self.baseBreakChance + Self.breakChancePerOpen * Double(max(0, t.opens - 1)))
            if Double.random(in: 0..<1) < chance {
                t.hasPresence = false
                t.emptyReason = .broken
            }
        }
        t.openedAt = date
        t.leaveRolls = 0
        transport = t
        armed = false
        log("상자 열림 · \(t.opens)번째" + (t.emptyReason == .broken ? " · 병 깨짐" : t.hasPresence ? " · 기척 있음" : " · 이미 비어 있음"))
        screen = .open
        save()
    }

    /// Opening an "until open" box observes the stretch since it was last closed: only now is it decided
    /// whether a cat is there, and the longer the stretch stayed quiet, the likelier it is. A cat found
    /// is kept; closing the box again starts a new, undecided stretch from nothing.
    private func observe(_ box: Transport, at date: Date = .now, thenArrive: Bool = false) {
        var t = box
        liftedAt = nil
        let minutes = t.openStretchMinutes
        let prior = t.segments?.count ?? 0
        let present = Double.random(in: 0..<1) < CarryStage.presenceChance(minutes: minutes, priorOpenings: prior)
        t.segments = (t.segments ?? []) + [Transport.Segment(minutes: minutes, present: present)]
        t.opens += 1
        t.hasPresence = present
        // Under five minutes nothing has settled in yet; after that it either slipped out or broke the vial.
        // The first opening is the vial's moment: it either broke or it didn't. After that the vial is
        // settled, and what goes wrong is the worn box letting the presence slip out.
        t.emptyReason = present ? nil : (prior == 0 ? .broken : .left)
        t.openedAt = date
        t.openSeconds = 0
        transport = t
        armed = false
        log("열 때까지 · \(Int(minutes))분 구간 관측 · " + (present ? "기척 있음" : "비어 있음"))
        if thenArrive { arriveUntilOpen() } else { screen = .open; save() }
    }

    /// Sends an "until open" box to the warehouse with whatever its openings found.
    func arriveUntilOpen() {
        guard var t = live ?? transport, t.mode == .untilOpen else { return }
        if t.openedAt == nil { observe(t, thenArrive: true); return }
        let found = (t.segments ?? []).contains { $0.present }
        t.duration = max(1, min(t.carried, Self.untilOpenCap))
        t.hasPresence = found
        if found { t.emptyReason = nil } else if t.emptyReason == nil { t.emptyReason = .left }
        t.openedAt = nil
        transport = t
        liftedAt = nil
        log("열 때까지 · 창고로 보냄 · 구간 \((t.segments ?? []).count)개")
        screen = .arrive
        save()
    }

    func closeBox() {
        guard var t = live ?? transport else { return }
        if t.mode == .untilOpen {
            // A new stretch: undecided again, from nothing.
            t.segmentStart = t.carried
            t.hasPresence = true
            t.emptyReason = nil
        }
        t.openedAt = nil
        t.lastTick = .now
        transport = t
        presenceJustLeft = false
        armed = false
        log("상자 닫힘")
        screen = t.arrived ? .arrive : .transport
        save()
    }

    func stackArrivedBox() -> Bool {
        guard let t = transport else { return false }
        boxes.append(StoredBox(open: !t.hasPresence, date: .now, minutes: t.duration / 60, mode: t.mode))
        let untilOpen = t.mode == .untilOpen
        let segments = t.segments ?? []
        // Any box that made it all the way, empty or not, may hide something in a corner.
        let longest = segments.map(\.minutes).max() ?? 0
        let itemChance = untilOpen && CarryStage(minutes: longest) >= .breaths ? Self.longItemChance : Self.itemChance
        if Double.random(in: 0..<1) < itemChance, let item = BoxItem.all.randomElement() {
            let found = FoundItem(itemID: item.id, date: .now)
            items.append(found)
            newItem = found
            log("상자에서 물건 발견 · \(item.name)")
        }
        var appeared: [FoundCat] = []
        if t.hasPresence {
            // An "until open" box is always opened to end it, so it leaves the unopened streak alone.
            if t.mode != .untilOpen { unopenedStreak = t.opens == 0 ? unopenedStreak + 1 : 0 }
            // Each cat is rolled on its own, so a long box can bring several grades.
            // An "until open" box brings the cats of each stretch where one was found, each rolled
            // on that stretch's own length; a box set by time rolls on its whole length.
            let rolls: [Double] = untilOpen
                ? segments.filter(\.present).flatMap { Array(repeating: $0.minutes, count: Self.catCount(minutes: $0.minutes)) }
                : Array(repeating: t.duration / 60, count: Self.catCount(minutes: t.duration / 60))
            for minutes in rolls {
                appeared.append(FoundCat(speciesID: rollSpecies(for: t, minutes: minutes, bonus: bonusNext).id, date: .now))
            }
            if bonusNext { log("다음 상자 보너스 사용") }
            bonusNext = false
        } else {
            if t.mode != .untilOpen { unopenedStreak = 0 }
            bonusNext = true
            log("빈 상자를 끝까지 옮김 · 다음 상자 보너스")
        }
        transport = nil
        UIApplication.shared.isIdleTimerDisabled = false
        // Plan: the cats turn up "a short time" after stacking, one after another.
        for (i, cat) in appeared.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2 + 0.5 * Double(i)) { [weak self] in
                guard let self else { return }
                self.cats.append(cat)
                if i == appeared.count - 1 {
                    self.newCatCount = appeared.count
                    self.newCatID = appeared[0].id
                }
                self.save()
            }
        }
        save()
        return !appeared.isEmpty
    }

    // MARK: Ticking

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if transport != nil { log("앱으로 돌아옴") }
            tick()
        case .background:
            if transport != nil { log("앱을 벗어남") }
            // iOS cannot stop the user from leaving, so leaving counts as opening the box.
            if let t = transport, t.openedAt == nil, screen == .transport { openBox() }
            save()
        default:
            break
        }
    }

    private func tick() {
        guard var t = live else { return }
        let before = t
        let now = Date.now
        let faceDown = motion.faceDown
        if faceDown != lastFaceDown, screen == .transport || screen == .open {
            log(faceDown ? "폰 엎음" : "폰 듦")
        }

        if screen == .transport, t.mode == .untilOpen {
            // Picking the phone up gives a few seconds to put it back before the box counts as opened.
            if let lifted = liftedAt {
                if faceDown {
                    liftedAt = nil
                    log("다시 엎음 · 계속 옮김")
                } else if now.timeIntervalSince(lifted) >= Self.liftGrace {
                    // The seconds spent deciding don't count as carrying.
                    observe(t, at: lifted)
                    lastFaceDown = faceDown
                    return
                }
            } else if !faceDown && armed && lastFaceDown {
                liftedAt = now
            }
        }

        if screen == .transport, t.mode == .untilOpen, liftedAt != nil {
            // Paused while the phone is up in the hand.
        } else if screen == .transport {
            if !faceDown && armed && lastFaceDown {
                // Lifting a face-down phone opens the box.
                transport = t
                openBox()
                lastFaceDown = faceDown
                return
            }
            // The box moves whether the phone lies face down or sits face up on this screen:
            // either way it isn't being used, as leaving the app counts as opening the box.
            if faceDown { armed = true }
            if t.arrivesAt == nil { t.carried += now.timeIntervalSince(t.lastTick) }
        } else if screen == .open, faceDown {
            // Putting the phone face down again closes the box.
            transport = t
            closeBox()
            lastFaceDown = faceDown
            return
        }

        // A box set by arrival time keeps to the clock: open, closed or away from the app.
        if let arrival = t.arrivesAt {
            t.carried = max(0, min(t.duration, t.duration - arrival.timeIntervalSince(now)))
        }

        if t.mode == .untilOpen, let openedAt = t.openedAt {
            // Nothing slips out of an "until open" box while it's open; the opening already decided it.
            // Left open past the cap, it goes to the warehouse as it is.
            if now.timeIntervalSince(openedAt) > Self.untilOpenCap {
                transport = t
                arriveUntilOpen()
                return
            }
        } else if let openedAt = t.openedAt {
            t.openSeconds = now.timeIntervalSince(openedAt)
            // Roll once per elapsed interval, including any missed while the app was in the background.
            let due = Int(t.openSeconds / leaveInterval)
            while t.hasPresence, (t.leaveRolls ?? 0) < due {
                t.leaveRolls = (t.leaveRolls ?? 0) + 1
                if Double.random(in: 0..<1) < leaveChance {
                    t.hasPresence = false
                    t.emptyReason = .left
                    presenceJustLeft = true
                    log("기척이 빠져나감 · 열어둔 지 \(Int(t.openSeconds))초")
                }
            }
        }

        t.lastTick = now
        lastFaceDown = faceDown
        let visibleChange = Int(t.carried) != Int(before.carried)
            || Int(t.openSeconds) != Int(before.openSeconds)
            || t.hasPresence != before.hasPresence
            || t.arrived != before.arrived
        if visibleChange { transport = t } else { live = t }

        if screen == .transport && t.mode == .untilOpen && t.arrived {
            log("열 때까지 · 12시간이 지나 저절로 열림")
            observe(t, thenArrive: true)
            return
        }
        if screen == .transport && t.arrived {
            log("창고 도착")
            screen = .arrive
            save()
        }
    }

    private func log(_ message: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        eventLog.insert("\(f.string(from: .now))  \(message)", at: 0)
        if eventLog.count > 30 { eventLog.removeLast() }
    }

    // MARK: Cats

    /// `minutes` is the stretch the cat came from: the whole carry, or one observed stretch of an "until open" box.
    private func rollSpecies(for t: Transport, minutes: Double, bonus: Bool) -> CatSpecies {
        let untilOpen = t.mode == .untilOpen
        let unopened = t.opens == 0 && !untilOpen
        let stage = CarryStage(minutes: minutes)
        var weights: [Grade: Double] = [:]
        for g in Grade.allCases { weights[g] = g.baseWeight }
        weights[.uncommon]! *= 1 + min(minutes / 120, 1) * 0.3
        if untilOpen && stage >= .warm { weights[.rare]! *= 2 } else if minutes >= 50 { weights[.rare]! *= 1.5 }
        if untilOpen && stage >= .silent { weights[.legend]! *= 2 }
        if unopened {
            weights[.rare]! *= 2
            weights[.legend]! *= 2
        }
        if bonus {
            weights[.rare]! *= Self.bonusMultiplier
            weights[.legend]! *= Self.bonusMultiplier
        }

        let legends = Catalog.all.filter { s in
            guard s.grade == .legend, let rule = s.legendRule else { return false }
            switch rule {
            case .overnight:
                // Any carry that was under way at 3 a.m., however its length was chosen.
                let end = Date.now, start = end.addingTimeInterval(-t.duration)
                let three = Calendar.current.nextDate(after: start, matching: DateComponents(hour: 3, minute: 0), matchingPolicy: .nextTime)
                return three.map { $0 <= end } ?? false
            case .tenUnopenedInARow: return unopenedStreak >= 10
            case .openedFiveTimes: return !untilOpen && t.opens >= 5 && t.hasPresence
            case .superposition: return untilOpen && stage >= .light
            }
        }
        if legends.isEmpty { weights[.legend] = 0 }

        let total = weights.values.reduce(0, +)
        var r = Double.random(in: 0..<total)
        var grade: Grade = .common
        for g in Grade.allCases {
            let w = weights[g] ?? 0
            if r < w { grade = g; break }
            r -= w
        }
        let pool = grade == .legend ? legends : Catalog.all.filter { $0.grade == grade }
        return pool.randomElement() ?? Catalog.all[0]
    }

    #if DEBUG
    /// Debug: drop a few random cats into the warehouse to test a crowded floor.
    func debugAddCats(_ n: Int) {
        for _ in 0..<n { cats.append(FoundCat(speciesID: Catalog.all.randomElement()!.id, date: .now)) }
        save()
    }

    /// Debug: stack a pile of mixed boxes to test the layered warehouse.
    func debugAddBoxes(_ n: Int) {
        for _ in 0..<n {
            let r = Double.random(in: 0..<1)
            boxes.append(StoredBox(open: r < 0.2, date: .now, crushed: r > 0.9 ? true : nil))
        }
        save()
    }

    /// Debug: pretend the next box hid an item, to see the find without waiting for a 3% roll.
    func debugFindItem() {
        guard let item = BoxItem.all.randomElement() else { return }
        let found = FoundItem(itemID: item.id, date: .now)
        items.append(found)
        newItem = found
        log("디버그: 물건 발견 · \(item.name)")
        save()
    }

    /// Debug: move the box on the way forward, to see "until open" stages without waiting hours.
    func debugAdvance(minutes: Double) {
        guard var t = live ?? transport else { return }
        t.carried = min(t.duration, t.carried + minutes * 60)
        transport = t
        log("디버그: 운반 \(Int(minutes))분 앞으로")
    }

    /// Debug: back to a brand-new install — empty warehouse, no box on the way, no cooldown or bonus.
    func debugReset() {
        transport = nil
        boxes = []
        cats = []
        unopenedStreak = 0
        blockedUntil = nil
        bonusNext = false
        newCatID = nil
        newCatCount = 0
        items = []
        newItem = nil
        presenceJustLeft = false
        screen = .start
        save()
        log("디버그: 전체 초기화")
    }
    #endif

    func firstFound(_ speciesID: String) -> FoundCat? {
        cats.filter { $0.speciesID == speciesID }.min { $0.date < $1.date }
    }

    var foundSpecies: Set<String> { Set(cats.map(\.speciesID)) }

    // MARK: Persistence

    private struct Snapshot: Codable {
        var transport: Transport?
        var boxes: [StoredBox]
        var cats: [FoundCat]
        var unopenedStreak: Int
        var blockedUntil: Date?
        var bonusNext: Bool?
        var items: [FoundItem]?
    }

    func save() {
        let snap = Snapshot(transport: live ?? transport, boxes: boxes, cats: cats, unopenedStreak: unopenedStreak, blockedUntil: blockedUntil, bonusNext: bonusNext, items: items)
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        transport = snap.transport
        boxes = snap.boxes
        cats = snap.cats
        unopenedStreak = snap.unopenedStreak
        blockedUntil = snap.blockedUntil
        bonusNext = snap.bonusNext ?? false
        items = snap.items ?? []
    }
}
