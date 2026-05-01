import AppKit
import Foundation

struct StockAlert: Codable, Identifiable {
    let symbol: String
    var upperBound: Double?
    var lowerBound: Double?
    var enabled: Bool = true

    var id: String { symbol }

    var isEmpty: Bool { upperBound == nil && lowerBound == nil }
}

struct StockNotification: Identifiable {
    let id = UUID()
    let symbol: String
    var title: String
    let message: String
    let isAbove: Bool
    var ltp: Double
    let timestamp: Date = Date()
}

final class StockAlertStore: ObservableObject {
    static let shared = StockAlertStore()

    private let key = "stockAlerts"
    @Published var alerts: [String: StockAlert] = [:]
    @Published var pendingNotifications: [StockNotification] = []
    private var firedKeys: Set<String> = []

    private static let aboveMessages = [
        "बल्ल माथि पुग्यो! 🚀",
        "उकालो लाग्यो भन्नुस्! 📈",
        "पैसा छाप्ने मेसिन! 💰",
        "ताली बजाउनुस्! 👏",
        "राम्रो दिन आयो! ✨",
        "हुर्रे! माथि पुग्यो! 🎉",
        "बुल मार्केट भाइब्स! 🐂",
    ]

    private static let belowMessages = [
        "ओहो! तल झर्‍यो! 📉",
        "होसियार! घट्दैछ! ⚠️",
        "किन्ने बेला हो कि? 🤔",
        "तल गयो भन्नुस्! 😬",
        "सावधान रहनुस्! 🔔",
        "ओरालो लाग्यो! 🎢",
        "पर्‍यो त पर्‍यो! 💸",
    ]

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: StockAlert].self, from: data) {
            self.alerts = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(alerts) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func alert(for symbol: String) -> StockAlert? {
        alerts[symbol]
    }

    func setAlert(_ alert: StockAlert) {
        if alert.isEmpty {
            alerts.removeValue(forKey: alert.symbol)
            firedKeys = firedKeys.filter { !$0.hasPrefix(alert.symbol + "-") }
        } else {
            alerts[alert.symbol] = alert
            firedKeys = firedKeys.filter { !$0.hasPrefix(alert.symbol + "-") }
        }
        save()
    }

    func removeAlert(for symbol: String) {
        alerts.removeValue(forKey: symbol)
        firedKeys = firedKeys.filter { !$0.hasPrefix(symbol + "-") }
        save()
    }

    func hasAlert(for symbol: String) -> Bool {
        guard let a = alerts[symbol] else { return false }
        return a.enabled && !a.isEmpty
    }

    func dismissNotification(_ id: UUID) {
        pendingNotifications.removeAll { $0.id == id }
    }

    func dismissAll() {
        pendingNotifications.removeAll()
    }

    func checkAlerts(stocks: [StockQuote]) {
        let stockMap = Dictionary(stocks.map { ($0.symbol, $0) }, uniquingKeysWith: { $1 })

        for stock in stocks {
            guard let alert = alerts[stock.symbol], alert.enabled else { continue }

            if let upper = alert.upperBound, stock.ltp >= upper {
                let key = "\(stock.symbol)-upper"
                if !firedKeys.contains(key) {
                    firedKeys.insert(key)
                    let msg = Self.aboveMessages.randomElement()!
                    let notif = StockNotification(
                        symbol: stock.symbol,
                        title: "\(stock.symbol) — Rs \(Self.fmt(stock.ltp))",
                        message: msg,
                        isAbove: true,
                        ltp: stock.ltp
                    )
                    pendingNotifications.append(notif)
                    NSSound(named: .init("Funk"))?.play()
                    var updated = alert
                    updated.upperBound = nil
                    if updated.isEmpty { removeAlert(for: stock.symbol) }
                    else { setAlert(updated) }
                }
            } else {
                firedKeys.remove("\(stock.symbol)-upper")
            }

            if let lower = alert.lowerBound, stock.ltp <= lower {
                let key = "\(stock.symbol)-lower"
                if !firedKeys.contains(key) {
                    firedKeys.insert(key)
                    let msg = Self.belowMessages.randomElement()!
                    let notif = StockNotification(
                        symbol: stock.symbol,
                        title: "\(stock.symbol) — Rs \(Self.fmt(stock.ltp))",
                        message: msg,
                        isAbove: false,
                        ltp: stock.ltp
                    )
                    pendingNotifications.append(notif)
                    NSSound(named: .init("Sosumi"))?.play()
                    var updated = alert
                    updated.lowerBound = nil
                    if updated.isEmpty { removeAlert(for: stock.symbol) }
                    else { setAlert(updated) }
                }
            } else {
                firedKeys.remove("\(stock.symbol)-lower")
            }
        }

        // Update live prices on existing pending notifications
        var changed = false
        for i in pendingNotifications.indices {
            let sym = pendingNotifications[i].symbol
            if let stock = stockMap[sym], stock.ltp != pendingNotifications[i].ltp {
                pendingNotifications[i].ltp = stock.ltp
                pendingNotifications[i].title = "\(sym) — Rs \(Self.fmt(stock.ltp))"
                changed = true
            }
        }
        if changed { objectWillChange.send() }
    }

    static func fmt(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
