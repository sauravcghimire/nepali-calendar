import SwiftUI

/// The full popover content: header with nav + picker, month grid, event details,
/// and the horoscope row below the grid.
struct CalendarView: View {
    // `model` is owned by this view — @StateObject is correct here.
    @StateObject private var model = CalendarViewModel()
    // `settings` and `loginItem` are singletons owned globally —
    // @ObservedObject avoids pretending this view owns their lifecycle.
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var loginItem = LoginItem.shared
    @ObservedObject private var updater = AppUpdater.shared
    @State private var showPicker = false
    @State private var calendarHeight: CGFloat = 0

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left: stocks
            if settings.showStocks {
                VStack {
                    StockPanel()
                    Spacer(minLength: 0)
                }
                .frame(width: 390, height: calendarHeight)
                .padding(14)

                Divider()
            }

            // Center: calendar — drives the overall height
            VStack(alignment: .leading, spacing: 12) {
                versionBar
                header

                MonthGrid(bsYear: model.bsYear,
                          bsMonth: model.bsMonth,
                          selectedDay: $model.selectedDay,
                          todayAD: model.today)

                Divider()

                EventsPanel(bsYear: model.bsYear,
                            bsMonth: model.bsMonth,
                            bsDay: model.selectedDay)

                if settings.showHoroscope {
                    Divider()

                    HoroscopeRow(bsYear: model.bsYear,
                                 bsMonth: model.bsMonth,
                                 bsDay: model.selectedDay)
                        .environmentObject(settings)
                }

                Divider()

                DateConverterPanel()

                // Footer
                HStack(spacing: 6) {
                    Button {
                        model.jumpToToday()
                    } label: {
                        Label("Today", systemImage: "calendar.badge.clock")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Toggle(isOn: Binding(
                        get: { loginItem.isEnabled },
                        set: { loginItem.setEnabled($0) }
                    )) {
                        Text("Open at login").font(.caption)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Start Nepali Calendar automatically when you log in to your Mac")

                    Spacer()

                    panelToggleBar

                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Label("Quit", systemImage: "power")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
            .frame(width: 480)
            .padding(14)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: CalendarHeightKey.self, value: geo.size.height)
                }
            )
            .onPreferenceChange(CalendarHeightKey.self) { calendarHeight = $0 }

            // Right: forex
            if settings.showForex {
                Divider()

                VStack {
                    ForexPanel()
                    Spacer(minLength: 0)
                }
                .frame(width: 260, height: calendarHeight)
                .padding(14)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .animation(.easeInOut(duration: 0.2), value: settings.showStocks)
        .animation(.easeInOut(duration: 0.2), value: settings.showHoroscope)
        .animation(.easeInOut(duration: 0.2), value: settings.showForex)
    }

    private struct CalendarHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

    private var panelToggleBar: some View {
        HStack(spacing: 2) {
            panelToggle(icon: "chart.line.uptrend.xyaxis",
                        label: "Stocks",
                        isOn: $settings.showStocks,
                        color: .cyan)
            panelToggle(icon: "sparkles",
                        label: "Rashifal",
                        isOn: $settings.showHoroscope,
                        color: .purple)
            panelToggle(icon: "dollarsign.arrow.circlepath",
                        label: "Forex",
                        isOn: $settings.showForex,
                        color: .orange)
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    private func panelToggle(icon: String, label: String,
                             isOn: Binding<Bool>, color: Color) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(isOn.wrappedValue ? color : .secondary.opacity(0.4))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isOn.wrappedValue ? color.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help("\(isOn.wrappedValue ? "Hide" : "Show") \(label)")
    }

    private var versionBar: some View {
        HStack(spacing: 6) {
            Text("v\(updater.currentVersion)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)

            if updater.isChecking {
                ProgressView()
                    .controlSize(.mini)
            } else if updater.updateAvailable, let latest = updater.latestVersion {
                if updater.isUpgrading {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.mini)
                        Text("Upgrading to v\(latest)…")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        updater.upgrade()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 10))
                            Text("Update to v\(latest)")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.accentColor))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let error = updater.upgradeError {
                Text(error)
                    .font(.system(size: 9))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }

            Spacer()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: model.prevMonth) {
                Image(systemName: "chevron.left")
            }
            .disabled(!model.canStep(by: -1))
            .buttonStyle(.bordered)

            Button(action: model.prevYear) {
                Image(systemName: "chevron.left.2")
            }
            .disabled(!model.canStep(by: -12))
            .buttonStyle(.bordered)
            .help("Previous year")

            Button {
                showPicker.toggle()
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(NepaliMonth.name(model.bsMonth)) \(NepaliNumerals.devanagari(model.bsYear))")
                        .font(.system(size: 14, weight: .semibold))
                    Text(model.gregorianLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPicker, arrowEdge: .top) {
                MonthYearPicker(availableYears: CalendarStore.shared.availableYears,
                                bsYear: $model.bsYear,
                                bsMonth: $model.bsMonth) {
                    showPicker = false
                }
            }

            Button(action: model.nextYear) {
                Image(systemName: "chevron.right.2")
            }
            .disabled(!model.canStep(by: 12))
            .buttonStyle(.bordered)
            .help("Next year")

            Button(action: model.nextMonth) {
                Image(systemName: "chevron.right")
            }
            .disabled(!model.canStep(by: 1))
            .buttonStyle(.bordered)
        }
    }
}

/// Shows the selected day's details: day label, tithi, AD date, event list.
private struct EventsPanel: View {
    let bsYear: Int
    let bsMonth: Int
    let bsDay: Int

    var body: some View {
        let info = CalendarStore.shared.byBs[bsYear]?[bsMonth]?[bsDay]
        // Weekends (Sun/Sat) count as holidays alongside the JSON flag.
        let isHoliday = CalendarStore.shared.isEffectiveHoliday(
            bsYear: bsYear, bsMonth: bsMonth, bsDay: bsDay)
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .center, spacing: 2) {
                Text(NepaliNumerals.devanagari(bsDay))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(isHoliday ? Color.red : .primary)
                Text(NepaliMonth.name(bsMonth))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 64)

            VStack(alignment: .leading, spacing: 3) {
                if let info {
                    Text(info.tithi).font(.system(size: 12, weight: .medium))
                    Text(String(format: "%04d-%02d-%02d (AD)",
                                info.adYear, info.adMonth, info.adDay))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if info.events.isEmpty {
                        Text("No events")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(info.events, id: \.self) { e in
                                HStack(alignment: .top, spacing: 4) {
                                    Text("•").foregroundStyle(.secondary)
                                    Text(e).font(.system(size: 12))
                                }
                            }
                        }
                    }
                } else {
                    Text("No data for this day.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

/// Owns the selected BS month/day and knows how to navigate and resolve today.
final class CalendarViewModel: ObservableObject {
    @Published var bsYear: Int
    @Published var bsMonth: Int
    @Published var selectedDay: Int

    let today: (bsYear: Int, bsMonth: Int, bsDay: Int)?

    init() {
        let store = CalendarStore.shared
        if let t = store.bsDate(forAD: Date()) {
            self.today = t
            self.bsYear = t.bsYear
            self.bsMonth = t.bsMonth
            self.selectedDay = t.bsDay
        } else {
            self.today = nil
            // Fallback to the first available (year, month) in the bundle
            let y = store.availableYears.first ?? 2082
            self.bsYear = y
            self.bsMonth = 1
            self.selectedDay = 1
        }
    }

    var gregorianLabel: String {
        guard let info = CalendarStore.shared.byBs[bsYear]?[bsMonth]?[1] else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM yyyy"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        var comps = DateComponents()
        comps.year = info.adYear; comps.month = info.adMonth; comps.day = info.adDay
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Kathmandu") ?? .current
        let date = cal.date(from: comps) ?? Date()
        return fmt.string(from: date)
    }

    func canStep(by delta: Int) -> Bool {
        CalendarStore.shared.step(bsYear: bsYear, bsMonth: bsMonth, by: delta) != nil
    }

    func step(by delta: Int) {
        if let (y, m) = CalendarStore.shared.step(bsYear: bsYear, bsMonth: bsMonth, by: delta) {
            bsYear = y; bsMonth = m
            selectedDay = min(selectedDay, CalendarStore.shared.days(bsYear: y, bsMonth: m).count)
            if selectedDay < 1 { selectedDay = 1 }
        }
    }

    func prevMonth() { step(by: -1) }
    func nextMonth() { step(by: 1) }
    func prevYear()  { step(by: -12) }
    func nextYear()  { step(by: 12) }

    func jumpToToday() {
        if let t = today {
            bsYear = t.bsYear; bsMonth = t.bsMonth; selectedDay = t.bsDay
        }
    }
}
