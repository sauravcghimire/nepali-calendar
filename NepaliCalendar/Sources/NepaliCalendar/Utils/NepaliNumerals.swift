import Foundation

/// Helpers for Devanagari-script numerals and Nepali month/weekday names.
enum NepaliNumerals {
    private static let digits: [Character] = ["०","१","२","३","४","५","६","७","८","९"]

    static func devanagari(_ n: Int) -> String {
        guard n >= 0 else { return "-" + devanagari(-n) }
        if n < 10 { return String(digits[n]) }
        var result = ""
        var value = n
        while value > 0 {
            result.insert(digits[value % 10], at: result.startIndex)
            value /= 10
        }
        return result
    }
}

enum NepaliMonth {
    private static let names = [
        "बैशाख","जेठ","असार","साउन","भदौ","असोज",
        "कार्तिक","मंसिर","पुष","माघ","फागुन","चैत"
    ]
    static func name(_ bsMonth: Int) -> String {
        guard (1...12).contains(bsMonth) else { return "-" }
        return names[bsMonth - 1]
    }
    static var all: [String] { names }
}

enum NepaliWeekday {
    /// Index 0 = Sunday ... 6 = Saturday
    private static let long = ["आइतबार","सोमबार","मंगलबार","बुधबार","बिहीबार","शुक्रबार","शनिबार"]
    private static let short = ["आइत","सोम","मंगल","बुध","बिही","शुक्र","शनि"]
    static func long(_ i: Int) -> String { long[safe: i] ?? "" }
    static func short(_ i: Int) -> String { short[safe: i] ?? "" }
    static var shortAll: [String] { short }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
