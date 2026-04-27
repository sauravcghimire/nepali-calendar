import Foundation
import SwiftUI

/// Lightweight UserDefaults-backed settings store.
final class Settings: ObservableObject {
    static let shared = Settings()

    private let defaultsKey = "defaultZodiacSign"
    private let favStocksKey = "favoriteStocks"
    private let showStocksKey = "showStocks"
    private let showHoroscopeKey = "showHoroscope"
    private let showForexKey = "showForex"

    @Published var defaultSign: ZodiacSign? {
        didSet {
            if let value = defaultSign {
                UserDefaults.standard.set(value.rawValue, forKey: defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            }
        }
    }

    @Published var favoriteStocks: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(favoriteStocks), forKey: favStocksKey)
        }
    }

    @Published var showStocks: Bool {
        didSet { UserDefaults.standard.set(showStocks, forKey: showStocksKey) }
    }

    @Published var showHoroscope: Bool {
        didSet { UserDefaults.standard.set(showHoroscope, forKey: showHoroscopeKey) }
    }

    @Published var showForex: Bool {
        didSet { UserDefaults.standard.set(showForex, forKey: showForexKey) }
    }

    func toggleFavoriteStock(_ symbol: String) {
        if favoriteStocks.contains(symbol) {
            favoriteStocks.remove(symbol)
        } else {
            favoriteStocks.insert(symbol)
        }
    }

    func isStockFavorite(_ symbol: String) -> Bool {
        favoriteStocks.contains(symbol)
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: defaultsKey),
           let sign = ZodiacSign(rawValue: raw) {
            self.defaultSign = sign
        } else {
            self.defaultSign = nil
        }
        if let arr = UserDefaults.standard.array(forKey: favStocksKey) as? [String] {
            self.favoriteStocks = Set(arr)
        } else {
            self.favoriteStocks = []
        }
        let ud = UserDefaults.standard
        self.showStocks = ud.object(forKey: showStocksKey) as? Bool ?? true
        self.showHoroscope = ud.object(forKey: showHoroscopeKey) as? Bool ?? true
        self.showForex = ud.object(forKey: showForexKey) as? Bool ?? true
    }
}
