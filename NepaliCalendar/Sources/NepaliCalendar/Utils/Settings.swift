import Foundation
import SwiftUI

/// Lightweight UserDefaults-backed settings store.
final class Settings: ObservableObject {
    static let shared = Settings()

    private let defaultsKey = "defaultZodiacSign"

    @Published var defaultSign: ZodiacSign? {
        didSet {
            if let value = defaultSign {
                UserDefaults.standard.set(value.rawValue, forKey: defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            }
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: defaultsKey),
           let sign = ZodiacSign(rawValue: raw) {
            self.defaultSign = sign
        } else {
            self.defaultSign = nil
        }
    }
}
