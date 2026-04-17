import SwiftUI

/// A 7-column grid of BS days for the currently-selected month.
struct MonthGrid: View {
    let bsYear: Int
    let bsMonth: Int
    /// Selected day in this month (1-based). Binding so the parent can react to taps.
    @Binding var selectedDay: Int

    /// AD date of "today" in Kathmandu — used to draw the "today" indicator.
    let todayAD: (bsYear: Int, bsMonth: Int, bsDay: Int)?

    var body: some View {
        let days = CalendarStore.shared.days(bsYear: bsYear, bsMonth: bsMonth)
        let firstWeekday = CalendarStore.shared.firstWeekday(bsYear: bsYear, bsMonth: bsMonth)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

        VStack(spacing: 8) {
            // Weekday header
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    Text(NepaliWeekday.shortAll[i])
                        .font(.caption)
                        .foregroundStyle(i == 6 ? Color.red.opacity(0.9) : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                // Empty leading cells so day 1 lands on the correct weekday column
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Color.clear.frame(height: 42)
                }
                ForEach(days, id: \.day) { entry in
                    DayCell(day: entry.day,
                            info: entry.info,
                            isToday: isToday(entry.day),
                            isSelected: entry.day == selectedDay,
                            weekdayIndex: (firstWeekday + entry.day - 1) % 7)
                        .onTapGesture { selectedDay = entry.day }
                }
            }
        }
    }

    private func isToday(_ day: Int) -> Bool {
        guard let t = todayAD else { return false }
        return t.bsYear == bsYear && t.bsMonth == bsMonth && t.bsDay == day
    }
}

private struct DayCell: View {
    let day: Int
    let info: NepaliDay
    let isToday: Bool
    let isSelected: Bool
    let weekdayIndex: Int // 0=Sun ... 6=Sat

    var body: some View {
        let isSaturday = weekdayIndex == 6
        let isRed = info.isHoliday || isSaturday

        VStack(spacing: 1) {
            Text(NepaliNumerals.devanagari(day))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(textColor(isRed: isRed))
            Text("\(info.adDay)")
                .font(.system(size: 9))
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isToday ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .help(tooltip)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(isSelected
                  ? Color.accentColor.opacity(0.20)
                  : (info.isHoliday ? Color.red.opacity(0.08) : Color.clear))
    }

    private func textColor(isRed: Bool) -> Color {
        if isSelected { return .primary }
        return isRed ? Color.red.opacity(0.9) : .primary
    }

    private var tooltip: String {
        var parts: [String] = [info.tithi]
        parts.append(contentsOf: info.events)
        return parts.filter { !$0.isEmpty }.joined(separator: " • ")
    }
}
