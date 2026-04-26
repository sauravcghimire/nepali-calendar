import AppKit
import Foundation

final class AppUpdater: ObservableObject {
    static let shared = AppUpdater()

    @Published var latestVersion: String?
    @Published var isChecking = false
    @Published var isUpgrading = false
    @Published var upgradeError: String?

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    var updateAvailable: Bool {
        guard let latest = latestVersion else { return false }
        return compare(latest, isNewerThan: currentVersion)
    }

    private let releaseURL = URL(string: "https://api.github.com/repos/sauravcghimire/nepali-calendar/releases/latest")!

    private init() {
        checkForUpdate()
    }

    func checkForUpdate() {
        guard !isChecking else { return }
        isChecking = true

        var request = URLRequest(url: releaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isChecking = false
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String else { return }
                self.latestVersion = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            }
        }.resume()
    }

    func upgrade() {
        guard !isUpgrading else { return }
        isUpgrading = true
        upgradeError = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", "brew upgrade --cask nepali-calendar 2>&1"]
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                                    encoding: .utf8) ?? ""

                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isUpgrading = false
                    if process.terminationStatus == 0 {
                        self.latestVersion = nil
                        self.relaunch()
                    } else {
                        self.upgradeError = output.trimmingCharacters(in: .whitespacesAndNewlines)
                            .components(separatedBy: "\n").last ?? "Upgrade failed"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isUpgrading = false
                    self.upgradeError = error.localizedDescription
                }
            }
        }
    }

    private func relaunch() {
        guard let appURL = Bundle.main.bundleURL as NSURL? else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: appURL as URL, configuration: config)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    }

    private func compare(_ a: String, isNewerThan b: String) -> Bool {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(partsA.count, partsB.count) {
            let va = i < partsA.count ? partsA[i] : 0
            let vb = i < partsB.count ? partsB[i] : 0
            if va > vb { return true }
            if va < vb { return false }
        }
        return false
    }
}
