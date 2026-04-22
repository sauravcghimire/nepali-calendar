import Foundation

// MARK: - JSON schema matching calendar/<bsYear>.json
//
// {
//   "bsYear": 2082,
//   "months": {
//       "1": { "1": { "events": [...], "tithi": "प्रतिपदा",
//                     "isHoliday": true, "adYear": 2025, "adMonth": 4, "adDay": 14 },
//              ... },
//       ...
//   }
// }

struct NepaliDay: Codable, Hashable {
    let events: [String]
    let tithi: String
    let isHoliday: Bool
    let adYear: Int
    let adMonth: Int
    let adDay: Int
}

struct NepaliYearFile: Codable {
    let bsYear: Int
    let months: [String: [String: NepaliDay]]
}

/// Loads the bundled <bsYear>.json files and provides lookups in both directions.
final class CalendarStore {
    static let shared = CalendarStore()

    /// bsYear -> bsMonth (1...12) -> bsDay (1...32) -> NepaliDay
    private(set) var byBs: [Int: [Int: [Int: NepaliDay]]] = [:]

    /// AD "yyyy-mm-dd" -> (bsYear, bsMonth, bsDay)
    private(set) var adToBs: [String: (Int, Int, Int)] = [:]

    private(set) var availableYears: [Int] = []

    private init() { load() }

    private func load() {
        let fm = FileManager.default
        let bundle = Bundle.module
        guard let calendarURL = bundle.url(forResource: "calendar", withExtension: nil) else {
            NSLog("[NepaliCalendar] calendar/ resource directory missing from bundle")
            return
        }
        let files = (try? fm.contentsOfDirectory(at: calendarURL,
                                                 includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        for url in files where url.pathExtension.lowercased() == "json" {
            guard let data = try? Data(contentsOf: url),
                  let year = try? decoder.decode(NepaliYearFile.self, from: data) else { continue }
            var monthsMap: [Int: [Int: NepaliDay]] = [:]
            for (mKey, days) in year.months {
                guard let m = Int(mKey) else { continue }
                var dayMap: [Int: NepaliDay] = [:]
                for (dKey, day) in days {
                    guard let d = Int(dKey) else { continue }
                    dayMap[d] = day
                    let adKey = Self.adKey(day.adYear, day.adMonth, day.adDay)
                    adToBs[adKey] = (year.bsYear, m, d)
                }
                monthsMap[m] = dayMap
            }
            byBs[year.bsYear] = monthsMap
        }
        availableYears = byBs.keys.sorted()
    }

    static func adKey(_ y: Int, _ m: Int, _ d: Int) -> String {
        String(format: "%04d-%02d-%02d", y, m, d)
    }

    /// BS date for a given AD Date. Returns nil if outside the shipped range.
    func bsDate(forAD date: Date) -> (bsYear: Int, bsMonth: Int, bsDay: Int)? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Kathmandu") ?? .current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return nil }
        return adToBs[Self.adKey(y, m, d)]
    }

    /// All days for a given BS month, sorted by day.
    func days(bsYear: Int, bsMonth: Int) -> [(day: Int, info: NepaliDay)] {
        guard let month = byBs[bsYear]?[bsMonth] else { return [] }
        return month
            .sorted { $0.key < $1.key }
            .map { (day: $0.key, info: $0.value) }
    }

    /// Day of week (0 = Sunday ... 6 = Saturday) for the first day of the month.
    func firstWeekday(bsYear: Int, bsMonth: Int) -> Int {
        guard let first = byBs[bsYear]?[bsMonth]?[1] else { return 0 }
        return weekday(adYear: first.adYear, adMonth: first.adMonth, adDay: first.adDay)
    }

    /// Weekday (0 = Sunday ... 6 = Saturday) for a given BS date. Returns nil
    /// if the date isn't covered by the bundled data.
    func weekday(bsYear: Int, bsMonth: Int, bsDay: Int) -> Int? {
        guard let info = byBs[bsYear]?[bsMonth]?[bsDay] else { return nil }
        return weekday(adYear: info.adYear, adMonth: info.adMonth, adDay: info.adDay)
    }

    private func weekday(adYear: Int, adMonth: Int, adDay: Int) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Kathmandu") ?? .current
        var comps = DateComponents()
        comps.year = adYear; comps.month = adMonth; comps.day = adDay
        let date = cal.date(from: comps) ?? Date()
        // Calendar.component(.weekday) returns 1 = Sunday ... 7 = Saturday.
        return cal.component(.weekday, from: date) - 1
    }

    /// Treats Saturdays AND Sundays as holidays, in addition to any date whose
    /// JSON entry has `isHoliday: true`. Returns `false` for unknown dates.
    func isEffectiveHoliday(bsYear: Int, bsMonth: Int, bsDay: Int) -> Bool {
        guard let info = byBs[bsYear]?[bsMonth]?[bsDay] else { return false }
        if info.isHoliday { return true }
        if let wd = weekday(bsYear: bsYear, bsMonth: bsMonth, bsDay: bsDay),
           wd == 0 || wd == 6 {
            return true
        }
        return false
    }

    /// Next/previous BS month, wrapping year if necessary. Returns nil at the edge of the data.
    func step(bsYear: Int, bsMonth: Int, by delta: Int) -> (Int, Int)? {
        var y = bsYear, m = bsMonth + delta
        while m > 12 { m -= 12; y += 1 }
        while m < 1  { m += 12; y -= 1 }
        guard byBs[y]?[m] != nil else { return nil }
        return (y, m)
    }
}
