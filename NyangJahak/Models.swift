import SwiftUI

enum Grade: String, Codable, CaseIterable, Identifiable {
    case common = "일반"
    case uncommon = "드문"
    case rare = "레어"
    case legend = "전설"

    var id: String { rawValue }

    /// The grade's name in the reader's language. The raw value stays Korean because it is saved.
    var label: String {
        switch self {
        case .common: return String(localized: "일반", bundle: .localized)
        case .uncommon: return String(localized: "드문", bundle: .localized)
        case .rare: return String(localized: "레어", bundle: .localized)
        case .legend: return String(localized: "전설", bundle: .localized)
        }
    }

    /// Base weights from the plan draft (60 / 28 / 10 / 2). Never shown on screen.
    var baseWeight: Double {
        switch self {
        case .common: return 60
        case .uncommon: return 28
        case .rare: return 10
        case .legend: return 2
        }
    }

    var chip: Color {
        switch self {
        case .common: return Color(hex: 0xE4DCCF)
        case .uncommon: return Color(hex: 0xCFE0EE)
        case .rare: return Color(hex: 0xE3D3EE)
        case .legend: return Color(hex: 0xF2DFB0)
        }
    }
}

/// How the length of a carry was chosen. The raw values are from the old "집중/밤샘 운반" modes and stay
/// as they are so saved boxes still load.
enum TransportMode: String, Codable, CaseIterable, Identifiable {
    /// A length of time: how long to focus.
    case byDuration = "집중 운반"
    /// An arrival time: when the box should reach the warehouse (handy for sleep).
    case byArrival = "밤샘 운반"
    /// No length at all: the box arrives when you open it, and only then is it decided what's inside.
    case untilOpen = "열 때까지"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .byDuration: return String(localized: "집중 시간 기준", bundle: .localized)
        case .byArrival: return String(localized: "도착 시간 기준", bundle: .localized)
        case .untilOpen: return String(localized: "열 때까지", bundle: .localized)
        }
    }

    var subtitle: String {
        switch self {
        case .byDuration: return String(localized: "얼마나 옮길지 정해요", bundle: .localized)
        case .byArrival: return String(localized: "언제 도착할지 정해요. 잘 때 좋아요", bundle: .localized)
        case .untilOpen: return String(localized: "다 했을 때 열어요", bundle: .localized)
        }
    }

    var symbol: String {
        switch self {
        case .byDuration: return "timer"
        case .byArrival: return "alarm"
        case .untilOpen: return "eye"
        }
    }
}

/// How settled the inside of an "until open" box has grown. Nothing is decided until it's opened;
/// the stage only shifts the odds, and the lid hints at it in words, never in numbers.
enum CarryStage: Int, Comparable {
    case uneasy, shifting, quieting, asleep, warm, breaths, light, silent

    init(minutes: Double) {
        switch minutes {
        case ..<10: self = .uneasy
        case ..<25: self = .shifting
        case ..<50: self = .quieting
        case ..<90: self = .asleep
        case ..<120: self = .warm
        case ..<180: self = .breaths
        case ..<360: self = .light
        default: self = .silent
        }
    }

    static func < (a: CarryStage, b: CarryStage) -> Bool { a.rawValue < b.rawValue }

    /// Chance something is in there when the box is opened: the chance it isn't halves every 10 minutes.
    /// `priorOpenings` wears the box: after the first opening, each one lets more slip out through the seams.
    static func presenceChance(minutes: Double, priorOpenings: Int = 0) -> Double {
        minutes < 5 ? 0 : (1 - pow(0.5, minutes / 10)) * (1 - wear(priorOpenings))
    }

    /// How worn the box is after this many openings: 10% more slips out per opening, up to half.
    static func wear(_ priorOpenings: Int) -> Double { min(0.5, 0.1 * Double(priorOpenings)) }

    /// The box's seams, once it has been opened before.
    static func wearNote(_ priorOpenings: Int) -> String? {
        switch priorOpenings {
        case ..<1: return nil
        case 1: return String(localized: "상자 모서리가 조금 해졌어요", bundle: .localized)
        case 2...3: return String(localized: "상자가 꽤 해졌어요", bundle: .localized)
        default: return String(localized: "상자가 너덜너덜해요", bundle: .localized)
        }
    }

    /// What you hear through the lid.
    var whisper: String {
        switch self {
        case .uneasy: return String(localized: "무언가 불안하게 움직여요", bundle: .localized)
        case .shifting: return String(localized: "뒤척이는 소리가 나요", bundle: .localized)
        case .quieting: return String(localized: "조용해지고 있어요", bundle: .localized)
        case .asleep: return String(localized: "깊이 잠든 것 같아요", bundle: .localized)
        case .warm: return String(localized: "상자가 따뜻해졌어요", bundle: .localized)
        case .breaths: return String(localized: "숨소리가 여럿 들려요", bundle: .localized)
        case .light: return String(localized: "틈으로 희미한 빛이 새어 나와요", bundle: .localized)
        case .silent: return String(localized: "아무 소리도 들리지 않아요", bundle: .localized)
        }
    }
}

/// Drawing parameters for one cat species. Mirrors the prototype's SVG template.
struct CatLook {
    var body: Color
    var chest: Color
    var stripe: Color
    var eyeL: Color
    var eyeR: Color
    var tail: Color? = nil
    var paw: Color? = nil
    var earOuter: Color? = nil
    var mask: Color? = nil
    var patchA: Color? = nil
    var patchB: Color? = nil
    var ear = Color(hex: 0xE9B5AC)
    var nose = Color(hex: 0xD98C82)
    var ruff = false
    var tailWidth: CGFloat = 9
    var bodyOpacity: Double = 1
    var bodyStripes = false
    var headStripes = false
    var spots = false
    var patches = false
    var stars = false
    var tape = false
    var earsUp = true
    var bigEars = false
    var folded = false
    var tufts = false
    var mask_ = false
    var wrinkles = false
    var muzzle = true
    /// Two cats in one: the right half is drawn again in these colors.
    var splitBody: Color? = nil
    var splitChest: Color? = nil

    init(body: UInt32, chest: UInt32, stripe: UInt32, eye: UInt32, eyeR: UInt32? = nil) {
        self.body = Color(hex: body)
        self.chest = Color(hex: chest)
        self.stripe = Color(hex: stripe)
        self.eyeL = Color(hex: eye)
        self.eyeR = Color(hex: eyeR ?? eye)
    }

    /// Everything one ink color, so only the outline (ears, ruff, tail) survives.
    var silhouette: CatLook {
        var l = self
        let ink = Color(hex: 0x2A221C)
        l.body = ink; l.chest = ink; l.stripe = ink; l.eyeL = ink; l.eyeR = ink
        l.tail = ink; l.paw = ink; l.earOuter = ink; l.mask = ink
        l.patchA = ink; l.patchB = ink; l.ear = ink; l.nose = ink
        l.bodyOpacity = 1; l.stars = false; l.tape = false
        return l
    }
}

enum LegendRule: String, Codable {
    /// The carry ran through the small hours (3 a.m.).
    case overnight
    case tenUnopenedInARow
    /// Opened five times or more, and whatever was inside is still there.
    case openedFiveTimes
    /// An "until open" box kept shut for three hours or more.
    case superposition
}

struct CatSpecies: Identifiable {
    let id: String
    let grade: Grade
    let look: CatLook
    var legendRule: LegendRule? = nil

    /// The id is the Korean name; other languages look it up in the string catalog.
    var name: String { NSLocalizedString(id, comment: "Cat species name") }
}

enum Catalog {
    static let all: [CatSpecies] = {
        func look(_ body: UInt32, _ chest: UInt32, _ stripe: UInt32, _ eye: UInt32, eyeR: UInt32? = nil, _ edit: (inout CatLook) -> Void = { _ in }) -> CatLook {
            var l = CatLook(body: body, chest: chest, stripe: stripe, eye: eye, eyeR: eyeR)
            edit(&l)
            return l
        }
        return [
            CatSpecies(id: "고등어", grade: .common, look: look(0xB9B6B1, 0xEFECE7, 0x7E7A75, 0x2E2A26) { $0.bodyStripes = true; $0.headStripes = true }),
            CatSpecies(id: "치즈", grade: .common, look: look(0xD9A066, 0xF4E3CC, 0xB8743A, 0x2E2A26) { $0.bodyStripes = true; $0.headStripes = true }),
            CatSpecies(id: "삼색", grade: .common, look: look(0xF4EEE4, 0xFBF8F3, 0xD9CFC0, 0x2E2A26) { $0.patches = true; $0.patchA = Color(hex: 0xD9A066); $0.patchB = Color(hex: 0x3F3A36) }),
            CatSpecies(id: "턱시도", grade: .common, look: look(0x2E2A26, 0xF4F0EA, 0x2E2A26, 0xE0B44A) { $0.paw = Color(hex: 0xF4F0EA) }),
            CatSpecies(id: "흰 고양이", grade: .common, look: look(0xF4EEE4, 0xFBF8F3, 0xE2D9CC, 0x6FA0C8)),
            CatSpecies(id: "검은 고양이", grade: .common, look: look(0x2A2622, 0x2A2622, 0x2A2622, 0xE0B44A) { $0.muzzle = false; $0.ear = Color(hex: 0x4A3F38) }),
            CatSpecies(id: "러시안 블루", grade: .uncommon, look: look(0x8E9AA8, 0x9EAAB7, 0x76828F, 0x5E8C62) { $0.ear = Color(hex: 0xB49AA0) }),
            CatSpecies(id: "샴", grade: .uncommon, look: look(0xEFE5D3, 0xF6F0E6, 0x6B5242, 0x4F7FB0) {
                let point = Color(hex: 0x6B5242)
                $0.mask = point; $0.mask_ = true; $0.earOuter = point; $0.paw = point; $0.tail = point; $0.ear = Color(hex: 0x8A6A56)
            }),
            CatSpecies(id: "스코티시 폴드", grade: .uncommon, look: look(0xC9C2B8, 0xEFECE7, 0xA39B90, 0xC9902A) { $0.earsUp = false; $0.folded = true; $0.headStripes = true }),
            CatSpecies(id: "노르웨이 숲", grade: .uncommon, look: look(0x8F7E6A, 0xF1EAE0, 0x6B5C4B, 0x5E8C62) { $0.ruff = true; $0.tailWidth = 15; $0.bodyStripes = true; $0.headStripes = true }),
            CatSpecies(id: "메인쿤", grade: .rare, look: look(0x7A5A3E, 0xE8DCC8, 0x5A412C, 0xC9902A) { $0.ruff = true; $0.tufts = true; $0.tailWidth = 15; $0.bodyStripes = true; $0.headStripes = true }),
            CatSpecies(id: "벵갈", grade: .rare, look: look(0xD9A866, 0xF4E3CC, 0x6B4A2A, 0x5E8C62) { $0.spots = true; $0.headStripes = true }),
            CatSpecies(id: "스핑크스", grade: .rare, look: look(0xE8C4B0, 0xF0D6C6, 0xC99C86, 0x7FA7C9) { $0.earsUp = false; $0.bigEars = true; $0.wrinkles = true; $0.tailWidth = 6 }),
            CatSpecies(id: "오드아이 흰 고양이", grade: .rare, look: look(0xF4EEE4, 0xFBF8F3, 0xE2D9CC, 0x7FA7C9, eyeR: 0xE0B44A)),
            CatSpecies(id: "별무늬 고양이", grade: .legend, look: look(0x2F3A5A, 0x3E4A6E, 0x2F3A5A, 0xF2D27A) { $0.stars = true }, legendRule: .overnight),
            CatSpecies(id: "반투명 고양이", grade: .legend, look: look(0xBFD4E0, 0xE3EEF4, 0xBFD4E0, 0x5E8C9A) { $0.bodyOpacity = 0.55 }, legendRule: .tenUnopenedInARow),
            CatSpecies(id: "골판지 무늬 고양이", grade: .legend, look: look(0xD6AE7E, 0xEBD8B0, 0xB48A58, 0x2E2A26) { $0.tape = true }, legendRule: .openedFiveTimes),
            CatSpecies(id: "중첩 고양이", grade: .legend, look: look(0xF4EEE4, 0xFBF8F3, 0xE2D9CC, 0x6FA0C8, eyeR: 0xE0B44A) {
                $0.splitBody = Color(hex: 0x2A2622); $0.splitChest = Color(hex: 0x3A3430)
            }, legendRule: .superposition),
        ]
    }()

    static func species(_ id: String) -> CatSpecies? { all.first { $0.id == id } }
}

/// Something other than a cat that very rarely turns up in a box.
struct BoxItem: Identifiable {
    let id: String
    /// Korean text, which is also the key into the string catalog.
    let nameKey: String
    let symbol: String
    let tint: Color
    /// One line for the find, in the same quiet voice as the cats.
    let noteKey: String

    var name: String { NSLocalizedString(nameKey, comment: "Item found in a box") }
    var note: String { NSLocalizedString(noteKey, comment: "Line shown with an item found in a box") }

    static let all: [BoxItem] = [
        BoxItem(id: "yarn", nameKey: "털실 뭉치", symbol: "circle.hexagongrid.fill", tint: Color(hex: 0xC4645A), noteKey: "누군가 한참 굴리고 논 것 같아요."),
        BoxItem(id: "key", nameKey: "낡은 열쇠", symbol: "key.fill", tint: Color(hex: 0xB08D3C), noteKey: "어느 문의 열쇠인지는 아무도 몰라요."),
        BoxItem(id: "bell", nameKey: "작은 방울", symbol: "bell.fill", tint: Color(hex: 0xD9A93E), noteKey: "흔들면 아주 작게 딸랑거려요."),
        BoxItem(id: "letter", nameKey: "봉투", symbol: "envelope.fill", tint: Color(hex: 0x8C7A66), noteKey: "받는 사람 칸이 비어 있어요."),
        BoxItem(id: "feather", nameKey: "깃털", symbol: "leaf.fill", tint: Color(hex: 0x7E8F7A), noteKey: "어디서 날아 들어왔을까요."),
        BoxItem(id: "fish", nameKey: "생선 모양 과자", symbol: "fish.fill", tint: Color(hex: 0x6E8FA8), noteKey: "반쯤 먹다 만 자국이 있어요."),
        BoxItem(id: "button", nameKey: "단추 하나", symbol: "circle.circle.fill", tint: Color(hex: 0x6B5A4A), noteKey: "실 한 가닥이 아직 붙어 있어요."),
    ]

    static func item(_ id: String) -> BoxItem? { all.first { $0.id == id } }
}

/// One item found in a box.
struct FoundItem: Codable, Identifiable {
    var id = UUID()
    var itemID: String
    var date: Date
}

/// The language the app is shown in: the device's, or one picked in the app's settings.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, ko, en

    var id: String { rawValue }
    static let storageKey = "appLanguage"

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }

    /// Each language's name in itself, so it can be found whatever the app is showing.
    var title: String {
        switch self {
        case .system: return String(localized: "기기 설정 따르기", bundle: .localized)
        case .ko: return "한국어"
        case .en: return "English"
        }
    }

    var locale: Locale {
        switch self {
        case .system: return .autoupdatingCurrent
        case .ko: return Locale(identifier: "ko_KR")
        case .en: return Locale(identifier: "en_US")
        }
    }

    /// Points every string lookup in the app at the chosen language right away, without a restart.
    func apply() {
        LanguageBundle.install()
        let code: String? = self == .system ? nil : rawValue
        LanguageBundle.chosen = code.flatMap { Bundle.main.path(forResource: $0, ofType: "lproj") }.flatMap(Bundle.init(path:))
    }
}

extension Bundle {
    /// Where String(localized:) should look: the language picked in the app, or the app's own choice.
    static var localized: Bundle { LanguageBundle.chosen ?? .main }
}

/// Bundle.main, but answering string lookups from the language picked in the app when there is one.
final class LanguageBundle: Bundle, @unchecked Sendable {
    static var chosen: Bundle?
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        object_setClass(Bundle.main, LanguageBundle.self)
    }

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let chosen = Self.chosen { return chosen.localizedString(forKey: key, value: value, table: tableName) }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

/// One box in the warehouse.
struct StoredBox: Codable, Identifiable {
    var id = UUID()
    var open: Bool
    var date: Date
    /// Abandoned on the way: stacked crushed (optional so older saves still load).
    var crushed: Bool? = nil
    /// How long it was carried and how, for the carry log (missing on boxes from 1.0).
    var minutes: Double? = nil
    var mode: TransportMode? = nil
    var isCrushed: Bool { crushed ?? false }
}

/// One cat found in the warehouse.
struct FoundCat: Codable, Identifiable {
    var id = UUID()
    var speciesID: String
    var date: Date
}

enum EmptyReason: String, Codable {
    case broken
    case left
}

/// A box being carried right now.
struct Transport: Codable {
    var mode: TransportMode
    var duration: TimeInterval
    var carried: TimeInterval = 0
    var opens = 0
    var hasPresence = true
    var emptyReason: EmptyReason? = nil
    var openedAt: Date? = nil
    var openSeconds: TimeInterval = 0
    /// How many leave rolls this opening has had (optional so older saves still load).
    var leaveRolls: Int?
    var lastTick: Date = .now
    /// Set for boxes chosen by arrival time: they reach the warehouse at this moment no matter how
    /// often they're opened on the way. (Optional so older saves still load.)
    var arrivesAt: Date? = nil
    /// "Until open" boxes: each opening observes the stretch carried since the last one.
    /// Where the current stretch began (in carried seconds), and what each opening found.
    var segmentStart: TimeInterval? = nil
    var segments: [Segment]? = nil

    struct Segment: Codable {
        var minutes: Double
        var present: Bool
    }

    /// Minutes in the stretch that hasn't been observed yet.
    var openStretchMinutes: Double { max(0, carried - (segmentStart ?? 0)) / 60 }

    var remaining: TimeInterval { max(0, duration - carried) }
    var progress: Double { duration > 0 ? min(1, carried / duration) : 1 }
    var arrived: Bool { carried >= duration }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum Palette {
    static let cardboard = Color(hex: 0xD6AE7E)
    static let cardboardEdge = Color(hex: 0xC49A68)
    static let flapLight = Color(hex: 0xDDB88A)
    static let flapSide = Color(hex: 0xCDA372)
    static let flapBottom = Color(hex: 0xD9B385)
    static let tape = Color(hex: 0xEBD8B0)
    static let inside = Color(hex: 0x7E5A37)
    static let wallTop = Color(hex: 0x9A7047)
    static let wallSide = Color(hex: 0x8C6440)
    static let wallBottom = Color(hex: 0x6E4E2F)
    static let paper = Color(hex: 0xFBFAF6)
    static let ground = Color(hex: 0xF3EEE6)
    static let floor = Color(hex: 0xE3D6C3)
    static let ink = Color(hex: 0x2B2118)
    static let inkSoft = Color(hex: 0x4A3826)
    static let muted = Color(hex: 0x6E6255)
    static let button = Color(hex: 0x2F2116)
    static let buttonText = Color(hex: 0xFBF5EA)
    static let risk = Color(hex: 0xC8653A)
    static let riskText = Color(hex: 0x8A3F1E)
    static let presence = Color(hex: 0x120E0B)
    static let glint = Color(hex: 0xE8D9A0)
}

enum Fonts {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .rounded) }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
}
