import Foundation

struct StockQuote: Identifiable {
    let symbol: String
    let ltp: Double
    let pointChange: Double
    let percentChange: Double
    let open: Double
    let high: Double
    let low: Double
    let volume: Double
    let prevClose: Double

    var id: String { symbol }

    var direction: Direction {
        if pointChange > 0 { return .up }
        if pointChange < 0 { return .down }
        return .unchanged
    }

    enum Direction {
        case up, down, unchanged
    }
}

final class StockStore: ObservableObject {
    static let shared = StockStore()

    @Published var stocks: [StockQuote] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastFetched: Date?
    @Published var isMarketDay = true

    private var refreshTimer: Timer?
    private let url = URL(string: "https://www.sharesansar.com/live-trading")!

    private init() {
        // Always fetch once on launch to show last trading day's data
        isMarketDay = !isTodayHoliday()
        fetch()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkAndFetch()
        }
    }

    func checkAndFetch() {
        isMarketDay = !isTodayHoliday()
        if isMarketDay {
            fetch()
        }
    }

    func fetch() {
        isLoading = true
        error = nil

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, err in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                if let err {
                    self.error = err.localizedDescription
                    return
                }
                guard let data, let html = String(data: data, encoding: .utf8) else {
                    self.error = "No data received"
                    return
                }

                self.stocks = Self.parse(html: html)
                self.lastFetched = Date()
                if self.stocks.isEmpty {
                    self.error = "No trading data found"
                }
            }
        }.resume()
    }

    private func isTodayHoliday() -> Bool {
        let store = CalendarStore.shared
        guard let today = store.bsDate(forAD: Date()) else { return false }
        return store.isEffectiveHoliday(
            bsYear: today.bsYear, bsMonth: today.bsMonth, bsDay: today.bsDay)
    }

    static func parse(html: String) -> [StockQuote] {
        var results: [StockQuote] = []

        guard let tbodyStart = html.range(of: "<tbody>", options: .caseInsensitive,
                                           range: html.range(of: "headFixed") != nil
                                           ? html.range(of: "headFixed")!.lowerBound..<html.endIndex
                                           : html.startIndex..<html.endIndex) else {
            return []
        }

        let searchStart = tbodyStart.upperBound
        guard let tbodyEnd = html.range(of: "</tbody>", options: .caseInsensitive,
                                         range: searchStart..<html.endIndex) else {
            return []
        }

        let tbody = String(html[searchStart..<tbodyEnd.lowerBound])
        let rows = tbody.components(separatedBy: "<tr")

        for row in rows {
            guard row.contains("<td") else { continue }
            let cells = extractCells(from: row)
            guard cells.count >= 10 else { continue }

            let symbol = extractLinkText(from: cells[1])
            guard !symbol.isEmpty else { continue }

            results.append(StockQuote(
                symbol: symbol,
                ltp: parseNum(cells[2]),
                pointChange: parseNum(cells[3]),
                percentChange: parseNum(cells[4]),
                open: parseNum(cells[5]),
                high: parseNum(cells[6]),
                low: parseNum(cells[7]),
                volume: parseNum(cells[8]),
                prevClose: parseNum(cells[9])
            ))
        }
        return results
    }

    private static func extractCells(from row: String) -> [String] {
        var cells: [String] = []
        var searchRange = row.startIndex..<row.endIndex

        while let tdStart = row.range(of: "<td", options: .caseInsensitive, range: searchRange) {
            guard let gtAfterTd = row.range(of: ">", range: tdStart.upperBound..<row.endIndex) else { break }
            let contentStart = gtAfterTd.upperBound
            guard let tdEnd = row.range(of: "</td>", options: .caseInsensitive,
                                         range: contentStart..<row.endIndex) else { break }
            cells.append(String(row[contentStart..<tdEnd.lowerBound]))
            searchRange = tdEnd.upperBound..<row.endIndex
        }
        return cells
    }

    private static func extractLinkText(from cell: String) -> String {
        if let aStart = cell.range(of: ">", range:
            (cell.range(of: "<a", options: .caseInsensitive)?.upperBound ?? cell.startIndex)..<cell.endIndex),
           let aEnd = cell.range(of: "</a>", options: .caseInsensitive) {
            return String(cell[aStart.upperBound..<aEnd.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return stripHTML(cell).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripHTML(_ str: String) -> String {
        str.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    private static func parseNum(_ str: String) -> Double {
        let cleaned = stripHTML(str)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
        return Double(cleaned) ?? 0
    }
}
