import SwiftUI

// MARK: Carry log

/// What the carry log works out from the stacked boxes. Boxes from 1.0 have no minutes: they still
/// count as boxes, just not toward time.
struct CarryLogSummary {
    let boxes: [StoredBox]
    let calendar: Calendar

    init(boxes: [StoredBox], calendar: Calendar = .logCalendar) {
        self.boxes = boxes
        self.calendar = calendar
    }

    func boxes(on day: Date) -> [StoredBox] {
        boxes.filter { calendar.isDate($0.date, inSameDayAs: day) }.sorted { $0.date < $1.date }
    }

    func minutes(_ list: [StoredBox]) -> Double { list.compactMap(\.minutes).reduce(0, +) }

    var thisWeek: [StoredBox] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return boxes.filter { week.contains($0.date) }
    }

    /// Days in a row, up to today, with at least one box carried all the way. A day not over yet
    /// doesn't break it: if today has nothing so far, the run counts back from yesterday.
    var streak: Int {
        let carried = Set(boxes.filter { !$0.isCrushed }.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: .now)
        if !carried.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day) ?? day }
        var run = 0
        while carried.contains(day) {
            run += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return run
    }
}

extension Calendar {
    /// The user's calendar, with weeks starting the way the chosen app language expects.
    static var logCalendar: Calendar {
        var c = Calendar.current
        c.locale = AppLanguage.current.locale
        return c
    }
}

struct CarryLogView: View {
    @EnvironmentObject var store: GameStore
    @State private var month = Calendar.logCalendar.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var selected = Calendar.logCalendar.startOfDay(for: .now)

    private var calendar: Calendar { .logCalendar }

    var body: some View {
        let log = CarryLogSummary(boxes: store.boxes, calendar: calendar)
        let week = log.thisWeek
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button { store.screen = .warehouse } label: {
                    Label("창고", systemImage: "chevron.left").font(Fonts.body(14)).foregroundStyle(Palette.ink)
                        .frame(minHeight: 44)
                }
                Text("운반 일지").font(Fonts.display(30)).foregroundStyle(Palette.ink)

                HStack(spacing: 10) {
                    stat("이번 주", durationLabel(log.minutes(week)), "상자 \(week.count)개")
                    stat("연속", String(localized: "\(log.streak)일", bundle: .localized), "끝까지 옮긴 날")
                }

                monthHeader
                MonthGrid(month: month, calendar: calendar, selected: $selected, log: log)

                dayDetail(log)

                if store.boxes.contains(where: { $0.minutes == nil }) {
                    Text("1.1보다 먼저 옮긴 상자는 시간이 기록되지 않아 개수만 셀 수 있어요.")
                        .font(Fonts.body(12)).foregroundStyle(Palette.muted)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Palette.ground.ignoresSafeArea())
    }

    private func stat(_ label: LocalizedStringKey, _ value: String, _ note: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(Fonts.body(12)).foregroundStyle(Palette.muted)
            Text(value).font(.system(size: 24, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(note).font(Fonts.body(12)).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Palette.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var monthHeader: some View {
        HStack {
            Text(month.formatted(.dateTime.year().month(.wide).locale(AppLanguage.current.locale)))
                .font(Fonts.body(17, .semibold)).foregroundStyle(Palette.ink)
            Spacer()
            Button { shift(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("이전 달"))
            Button { shift(1) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("다음 달"))
            .disabled(calendar.isDate(month, equalTo: .now, toGranularity: .month))
        }
        .foregroundStyle(Palette.ink)
        .padding(.top, 4)
    }

    private func shift(_ months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: month) else { return }
        month = next
    }

    @ViewBuilder
    private func dayDetail(_ log: CarryLogSummary) -> some View {
        let list = log.boxes(on: selected)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(selected.formatted(.dateTime.month(.wide).day().weekday(.wide).locale(AppLanguage.current.locale)))
                    .font(Fonts.body(15, .semibold)).foregroundStyle(Palette.ink)
                Spacer()
                if log.minutes(list) > 0 {
                    Text(durationLabel(log.minutes(list))).font(Fonts.body(13, .semibold)).foregroundStyle(Palette.inkSoft)
                }
            }
            if list.isEmpty {
                Text("이날은 옮긴 상자가 없어요.").font(Fonts.body(13)).foregroundStyle(Palette.muted)
            } else {
                ForEach(list) { box in row(box) }
            }
        }
        .padding(16)
        .background(Palette.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func row(_ box: StoredBox) -> some View {
        HStack(spacing: 12) {
            MiniBox(box: box).frame(width: 30, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(box.minutes.map(durationLabel) ?? String(localized: "시간 기록 없음", bundle: .localized))
                    .font(Fonts.body(14, .semibold)).foregroundStyle(Palette.ink)
                Text(detail(box)).font(Fonts.body(12)).foregroundStyle(Palette.muted)
            }
            Spacer()
            Text(box.date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(AppLanguage.current.locale)))
                .font(Fonts.body(12).monospacedDigit()).foregroundStyle(Palette.muted)
        }
        .accessibilityElement(children: .combine)
    }

    private func detail(_ box: StoredBox) -> String {
        let state = box.isCrushed ? String(localized: "그만둠", bundle: .localized)
            : box.open ? String(localized: "빈 상자", bundle: .localized)
            : String(localized: "기척 있음", bundle: .localized)
        guard let mode = box.mode else { return state }
        return "\(mode.label) · \(state)"
    }
}

/// One month, a week to a row. Each day shows its boxes as a little stack, so busy days stand taller.
private struct MonthGrid: View {
    let month: Date
    let calendar: Calendar
    @Binding var selected: Date
    let log: CarryLogSummary

    var body: some View {
        let days = gridDays
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { s in
                    Text(s).font(Fonts.body(11)).foregroundStyle(Palette.muted).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day { cell(day) } else { Color.clear.frame(height: 62) }
                }
            }
        }
    }

    private func cell(_ day: Date) -> some View {
        let boxes = log.boxes(on: day)
        let isSelected = calendar.isDate(day, inSameDayAs: selected)
        let isToday = calendar.isDateInToday(day)
        let future = day > Date.now
        return Button { selected = day } label: {
            VStack(spacing: 3) {
                // Up to four boxes, newest on top; a "+" for more.
                VStack(spacing: 1) {
                    if boxes.count > 4 {
                        Text("+\(boxes.count - 4)").font(.system(size: 8, weight: .semibold)).foregroundStyle(Palette.inkSoft)
                    }
                    ForEach(Array(boxes.suffix(4).reversed().enumerated()), id: \.offset) { _, box in
                        MiniBox(box: box).frame(width: 18, height: 8)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                Text("\(calendar.component(.day, from: day))")
                    .font(Fonts.body(12, isToday ? .bold : .regular))
                    .foregroundStyle(future ? Palette.muted.opacity(0.5) : Palette.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .padding(.vertical, 4)
            .background(isSelected ? Palette.paper : .clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color(hex: 0x6E5034) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(future)
        .accessibilityLabel(Text("\(day.formatted(.dateTime.month().day().locale(AppLanguage.current.locale))), 상자 \(boxes.count)개"))
    }

    /// The month's days, with blanks before the first so it lines up under its weekday.
    private var gridDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let first = calendar.dateInterval(of: .month, for: month)?.start else { return [] }
        let lead = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: lead) + range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: first) }
    }

    private var weekdaySymbols: [String] {
        let s = calendar.veryShortWeekdaySymbols
        let i = calendar.firstWeekday - 1
        return Array(s[i...] + s[..<i])
    }
}

/// A box drawn small for the log: taped and closed if something was inside, open if empty, dented if given up.
private struct MiniBox: View {
    let box: StoredBox

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: max(1, h * 0.15))
                    .fill(box.isCrushed ? Color(hex: 0xC49A68) : Palette.cardboard)
                Rectangle().fill(box.open ? Palette.inside : Color(hex: 0xE3C297)).frame(height: max(1, h * 0.22))
                if !box.open && !box.isCrushed {
                    Rectangle().fill(Palette.tape).frame(width: w * 0.22)
                }
            }
            .rotationEffect(.degrees(box.isCrushed ? -6 : 0))
            .opacity(box.isCrushed ? 0.7 : 1)
        }
    }
}
