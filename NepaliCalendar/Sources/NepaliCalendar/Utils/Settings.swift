import Foundation
import SwiftUI

/// Lightweight UserDefaults-backed settings store.
final class Settings: ObservableObject {
    static let shared = Settings()

    private let defaultsKey = "defaultZodiacSign"
    private let favStocksKey = "favoriteStocks"

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
    }
}
