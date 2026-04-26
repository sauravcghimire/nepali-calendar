import Foundation

struct ForexRate: Codable, Identifiable {
    let iso3: String
    let name: String
    let unit: Int
    let buy: String
    let sell: String
    let date: String

    var id: String { iso3 }

    enum CodingKeys: String, CodingKey {
        case iso3, name, unit, buy, sell, date
    }
}

final class ForexStore: ObservableObject {
    static let shared = ForexStore()

    @Published var rates: [ForexRate] = []
    @Published var lastUpdated: String = ""
    @Published var isLoading = false
    @Published var error: String?

    private let url = URL(string: "https://www.nrb.org.np/api/forex/v1/app-rate")!
    private var refreshTimer: Timer?

    private init() {
        fetch()
        // Refresh every 30 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.fetch()
        }
    }

    func fetch() {
        isLoading = true
        error = nil

        URLSession.shared.dataTask(with: url) { [weak self] data, response, err in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                if let err {
                    self.error = err.localizedDescription
                    return
                }
                guard let data else {
                    self.error = "No data received"
                    return
                }
                do {
                    let decoded = try JSONDecoder().decode([ForexRate].self, from: data)
                    self.rates = decoded
                    self.lastUpdated = decoded.first?.date ?? ""
                } catch {
                    self.error = "Parse error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}
