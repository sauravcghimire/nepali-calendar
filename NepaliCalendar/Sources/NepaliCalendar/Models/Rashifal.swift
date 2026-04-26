import Foundation

/// The twelve zodiac signs in the order the app displays them.
/// The `key` must match the keys used inside rashifal JSON files.
enum ZodiacSign: String, CaseIterable, Identifiable, Codable {
    case mesh       // मेष
    case brish      // वृष (brish/vrish)
    case mithun     // मिथुन
    case karkat     // कर्कट
    case singha     // सिंह
    case kanya      // कन्या
    case tula       // तुला
    case brischik   // वृश्चिक
    case dhanu      // धनु
    case makar      // मकर
    case kumbha     // कुम्भ
    case meen       // मीन

    var id: String { rawValue }

    var nepaliName: String {
        switch self {
        case .mesh:     return "मेष"
        case .brish:    return "वृष"
        case .mithun:   return "मिथुन"
        case .karkat:   return "कर्कट"
        case .singha:   return "सिंह"
        case .kanya:    return "कन्या"
        case .tula:     return "तुला"
        case .brischik: return "वृश्चिक"
        case .dhanu:    return "धनु"
        case .makar:    return "मकर"
        case .kumbha:   return "कुम्भ"
        case .meen:     return "मीन"
        }
    }

    var englishName: String {
        switch self {
        case .mesh:     return "Aries"
        case .brish:    return "Taurus"
        case .mithun:   return "Gemini"
        case .karkat:   return "Cancer"
        case .singha:   return "Leo"
        case .kanya:    return "Virgo"
        case .tula:     return "Libra"
        case .brischik: return "Scorpio"
        case .dhanu:    return "Sagittarius"
        case .makar:    return "Capricorn"
        case .kumbha:   return "Aquarius"
        case .meen:     return "Pisces"
        }
    }

    var symbol: String {
        switch self {
        case .mesh:     return "♈"
        case .brish:    return "♉"
        case .mithun:   return "♊"
        case .karkat:   return "♋"
        case .singha:   return "♌"
        case .kanya:    return "♍"
        case .tula:     return "♎"
        case .brischik: return "♏"
        case .dhanu:    return "♐"
        case .makar:    return "♑"
        case .kumbha:   return "♒"
        case .meen:     return "♓"
        }
    }
}

/// Monthly rashifal JSON schema expected at rashifal/<bsYear>/<bsMonth>.json
///
/// The app is permissive about the top-level shape. It accepts all of:
///
/// Shape A — the shape shipped by this project:
/// {
///   "bsYear": 2083, "bsMonth": 1,
///   "days": {
///     "1": { "mesh": { "en": "...", "ne": "..." }, "brish": {...}, ... },
///     "2": { ... }
///   }
/// }
///
/// Shape B (day-keyed, predictions as plain strings):
/// { "1": { "mesh": "…", "brish": "…" }, "2": { ... } }
///
/// Shape C (sign-keyed):
/// { "mesh": { "1": "…", "2": "…" }, "brish": { ... } }
///
/// Prediction values may be a plain string OR `{ "ne": "...", "en": "..." }` —
/// the loader prefers Nepali (`ne`), then falls back to `en`, `text`,
/// `prediction`, `rashifal`.
struct RashifalStore {
    /// Prediction text (may be nil if the file is absent or the day has no entry).
    static func prediction(bsYear: Int, bsMonth: Int, bsDay: Int, sign: ZodiacSign) -> String? {
        let monthly = loadMonth(bsYear: bsYear, bsMonth: bsMonth)
        return monthly?.prediction(day: bsDay, sign: sign)
    }

    /// Predictions for all 12 signs on a given day.
    static func predictions(bsYear: Int, bsMonth: Int, bsDay: Int)
        -> [(sign: ZodiacSign, text: String)] {
        let monthly = loadMonth(bsYear: bsYear, bsMonth: bsMonth)
        return ZodiacSign.allCases.map {
            (sign: $0, text: monthly?.prediction(day: bsDay, sign: $0) ?? "")
        }
    }

    // MARK: - Internal

    private struct Monthly {
        /// day -> sign.rawValue -> text
        let byDay: [Int: [String: String]]

        func prediction(day: Int, sign: ZodiacSign) -> String? {
            byDay[day]?[sign.rawValue]
        }
    }

    private static var cache: [String: Monthly] = [:]
    private static let cacheQueue = DispatchQueue(label: "rashifal.cache")

    private static func loadMonth(bsYear: Int, bsMonth: Int) -> Monthly? {
        let key = "\(bsYear)-\(bsMonth)"
        return cacheQueue.sync {
            if let cached = cache[key] { return cached }
            guard let data = readData(bsYear: bsYear, bsMonth: bsMonth) else {
                cache[key] = Monthly(byDay: [:])
                return cache[key]
            }
            let monthly = parse(data: data)
            cache[key] = monthly
            return monthly
        }
    }

    /// Default locations the app looks in (outside the bundle) so users can
    /// drop new rashifal files in without rebuilding. Override via
    /// `UserDefaults.standard.set(path, forKey: "rashifalPath")`.
    private static var externalRoots: [URL] {
        var roots: [URL] = []
        let fm = FileManager.default

        if let override = UserDefaults.standard.string(forKey: "rashifalPath") {
            roots.append(URL(fileURLWithPath: (override as NSString).expandingTildeInPath,
                             isDirectory: true))
        }
        if let appSupport = try? fm.url(for: .applicationSupportDirectory,
                                        in: .userDomainMask,
                                        appropriateFor: nil,
                                        create: false) {
            roots.append(appSupport.appendingPathComponent("NepaliCalendar/rashifal",
                                                           isDirectory: true))
        }
        return roots
    }

    private static func readData(bsYear: Int, bsMonth: Int) -> Data? {
        let monthPadded = String(format: "%02d", bsMonth)
        let monthShort  = String(bsMonth)

        // 1. External user-editable locations (highest priority)
        for root in externalRoots {
            for month in [monthPadded, monthShort] {
                let url = root
                    .appendingPathComponent("\(bsYear)")
                    .appendingPathComponent("\(month).json")
                if let data = try? Data(contentsOf: url) { return data }
            }
        }

        // 2. Bundled fallback (shipped with the .app)
        let bundle = Bundle.module
        for month in [monthPadded, monthShort] {
            if let url = bundle.url(forResource: month,
                                    withExtension: "json",
                                    subdirectory: "rashifal/\(bsYear)") {
                return try? Data(contentsOf: url)
            }
        }
        return nil
    }

    private static func parse(data: Data) -> Monthly {
        let json = try? JSONSerialization.jsonObject(with: data)
        guard let root = json as? [String: Any] else { return Monthly(byDay: [:]) }

        // Shape A: { "days": { "1": { "mesh": {...}, ... }, ... }, ... }
        if let days = root["days"] as? [String: Any] {
            return Monthly(byDay: dayKeyedMap(days))
        }

        // Shape B vs C: sniff by inspecting top-level keys.
        let looksDayKeyed = root.keys.contains { Int($0) != nil }
        if looksDayKeyed {
            return Monthly(byDay: dayKeyedMap(root))
        }

        // Shape C: sign-keyed at the top level.
        var byDay: [Int: [String: String]] = [:]
        for (signKey, val) in root {
            let sign = canonicalSign(for: signKey) ?? signKey
            guard let days = val as? [String: Any] else { continue }
            for (dayKey, text) in days {
                guard let day = Int(dayKey) else { continue }
                byDay[day, default: [:]][sign] = textOf(text)
            }
        }
        return Monthly(byDay: byDay)
    }

    /// Convert { "<day>": { "<sign>": <value> } } → [day: [sign: text]]
    private static func dayKeyedMap(_ days: [String: Any]) -> [Int: [String: String]] {
        var byDay: [Int: [String: String]] = [:]
        for (dayKey, val) in days {
            guard let day = Int(dayKey),
                  let signs = val as? [String: Any] else { continue }
            byDay[day] = flatten(signs)
        }
        return byDay
    }

    private static func flatten(_ signMap: [String: Any]) -> [String: String] {
        var out: [String: String] = [:]
        for (rawKey, val) in signMap {
            let key = canonicalSign(for: rawKey) ?? rawKey
            out[key] = textOf(val)
        }
        return out
    }

    /// Unwrap either a plain string or an object with localized/aliased fields.
    /// Preference order: ne > text > prediction > rashifal > en.
    private static func textOf(_ any: Any) -> String {
        if let s = any as? String { return s }
        if let d = any as? [String: Any] {
            for key in ["ne", "text", "prediction", "rashifal", "en"] {
                if let s = d[key] as? String { return s }
            }
        }
        return ""
    }

    /// Accept common alternate spellings for sign keys.
    private static func canonicalSign(for key: String) -> String? {
        let k = key.lowercased()
        let aliases: [String: String] = [
            "aries": "mesh", "mesh": "mesh", "mesha": "mesh", "मेष": "mesh",
            "taurus": "brish", "vrish": "brish", "brish": "brish", "brisha": "brish",
            "vrisha": "brish", "वृष": "brish", "वृषभ": "brish",
            "gemini": "mithun", "mithun": "mithun", "मिथुन": "mithun",
            "cancer": "karkat", "karkat": "karkat", "कर्कट": "karkat", "कर्क": "karkat",
            "leo": "singha", "singha": "singha", "simha": "singha",
            "सिंह": "singha",
            "virgo": "kanya", "kanya": "kanya", "कन्या": "kanya",
            "libra": "tula", "tula": "tula", "तुला": "tula",
            "scorpio": "brischik", "brischik": "brischik",
            "vrishchik": "brischik", "vrischik": "brischik",
            "वृश्चिक": "brischik",
            "sagittarius": "dhanu", "dhanu": "dhanu", "धनु": "dhanu",
            "capricorn": "makar", "makar": "makar", "मकर": "makar",
            "aquarius": "kumbha", "kumbha": "kumbha", "कुम्भ": "kumbha",
            "pisces": "meen", "meen": "meen", "min": "meen", "मीन": "meen"
        ]
        return aliases[k] ?? aliases[key]
    }
}
