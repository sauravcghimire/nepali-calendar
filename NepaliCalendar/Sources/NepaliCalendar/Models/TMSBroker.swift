import AppKit
import Foundation
import Vision

struct Broker: Identifiable, Codable {
    let number: String
    let name: String
    let address: String
    let phone: String
    let tmsLink: String?

    var id: String { number }

    var tmsBaseURL: String {
        let num = Int(number) ?? 0
        let padded = String(format: "%02d", num)
        return "https://tms\(padded).nepsetms.com.np"
    }
}

struct TMSSession: Codable {
    let brokerNumber: String
    let jwt: String
    let sessionId: String
    let userName: String
    let savedAt: Date
}

final class TMSStore: ObservableObject {
    static let shared = TMSStore()

    private let brokerKey = "selectedBroker"
    private let sessionKey = "tmsSession"

    @Published var brokers: [Broker] = []
    @Published var isLoadingBrokers = false
    @Published var brokerError: String?

    @Published var selectedBroker: Broker? {
        didSet {
            if let b = selectedBroker, let data = try? JSONEncoder().encode(b) {
                UserDefaults.standard.set(data, forKey: brokerKey)
            } else {
                UserDefaults.standard.removeObject(forKey: brokerKey)
            }
        }
    }

    @Published var session: TMSSession? {
        didSet {
            if let s = session, let data = try? JSONEncoder().encode(s) {
                UserDefaults.standard.set(data, forKey: sessionKey)
            } else {
                UserDefaults.standard.removeObject(forKey: sessionKey)
            }
        }
    }

    @Published var isLoggingIn = false
    @Published var loginError: String?

    var isConnected: Bool { session != nil }

    private init() {
        if let data = UserDefaults.standard.data(forKey: brokerKey),
           let broker = try? JSONDecoder().decode(Broker.self, from: data) {
            self.selectedBroker = broker
        }
        if let data = UserDefaults.standard.data(forKey: sessionKey),
           let sess = try? JSONDecoder().decode(TMSSession.self, from: data) {
            self.session = sess
        }
    }

    // MARK: - Broker List

    func fetchBrokers() {
        guard !isLoadingBrokers else { return }
        isLoadingBrokers = true
        brokerError = nil
        brokers = []

        Task {
            var all: [Broker] = []
            let total = 200
            let pageSize = 50
            var start = 0
            var draw = 1

            while start < total {
                guard let url = URL(string: "https://www.sharesansar.com/broker-list?draw=\(draw)&start=\(start)&length=\(pageSize)") else { break }
                var req = URLRequest(url: url)
                req.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
                req.setValue("application/json", forHTTPHeaderField: "Accept")

                do {
                    let (data, _) = try await URLSession.shared.data(for: req)
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    guard let records = json?["data"] as? [[String: Any]] else { break }
                    if records.isEmpty { break }

                    for r in records {
                        guard let num = r["broker_number"] as? String else { continue }
                        if num.contains("_RWS") { continue }
                        let name = (r["broker_name"] as? String ?? "")
                            .replacingOccurrences(of: "&amp;", with: "&")
                        let broker = Broker(
                            number: num,
                            name: name,
                            address: r["broker_address"] as? String ?? "",
                            phone: r["broker_phone"] as? String ?? "",
                            tmsLink: r["tms_link"] as? String
                        )
                        all.append(broker)
                    }
                } catch {
                    await MainActor.run { self.brokerError = error.localizedDescription }
                    break
                }

                start += pageSize
                draw += 1
            }

            let sorted = all.sorted { (Int($0.number) ?? 0) < (Int($1.number) ?? 0) }
            await MainActor.run {
                self.brokers = sorted
                self.isLoadingBrokers = false
            }
        }
    }

    // MARK: - Captcha OCR

    private func solveCaptchaOCR(_ image: NSImage) -> String {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let cg = bitmap.cgImage else { return "" }

        let processed = preprocessCaptcha(cg)

        var recognized = ""
        let request = VNRecognizeTextRequest { req, _ in
            guard let results = req.results as? [VNRecognizedTextObservation] else { return }
            let texts = results.compactMap { $0.topCandidates(1).first?.string }
            recognized = texts.joined()
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.customWords = []
        request.revision = VNRecognizeTextRequestRevision3

        let handler = VNImageRequestHandler(cgImage: processed, options: [:])
        try? handler.perform([request])

        return recognized
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }

    private func preprocessCaptcha(_ source: CGImage) -> CGImage {
        let w = source.width
        let h = source.height
        let scale = 3
        let outW = w * scale
        let outH = h * scale

        guard let ctx = CGContext(
            data: nil,
            width: outW,
            height: outH,
            bitsPerComponent: 8,
            bytesPerRow: outW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return source }

        ctx.interpolationQuality = .high
        ctx.draw(source, in: CGRect(x: 0, y: 0, width: outW, height: outH))

        guard let scaled = ctx.makeImage() else { return source }

        guard let dataProvider = scaled.dataProvider,
              let pixelData = dataProvider.data,
              let rawPtr = CFDataGetBytePtr(pixelData) else { return scaled }

        let bufferLen = outW * outH * 4
        let mutableData = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferLen)
        defer { mutableData.deallocate() }
        mutableData.initialize(from: rawPtr, count: bufferLen)

        for i in stride(from: 0, to: bufferLen, by: 4) {
            let r = Int(mutableData[i])
            let g = Int(mutableData[i + 1])
            let b = Int(mutableData[i + 2])
            let gray = (r * 299 + g * 587 + b * 114) / 1000
            let bw: UInt8 = gray < 140 ? 0 : 255
            mutableData[i] = bw
            mutableData[i + 1] = bw
            mutableData[i + 2] = bw
            mutableData[i + 3] = 255
        }

        guard let outCtx = CGContext(
            data: mutableData,
            width: outW,
            height: outH,
            bitsPerComponent: 8,
            bytesPerRow: outW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return scaled }

        return outCtx.makeImage() ?? scaled
    }

    private static let maxCaptchaRetries = 5

    // MARK: - Login

    func login(username: String, password: String) {
        guard let broker = selectedBroker else { return }
        isLoggingIn = true
        loginError = nil

        Task {
            await loginWithRetry(base: broker.tmsBaseURL, username: username, password: password, attempt: 1)
        }
    }

    private func loginWithRetry(base: String, username: String, password: String, attempt: Int) async {
        do {
            let (cid, solved) = try await fetchAndSolveCaptcha(base: base)

            if solved.isEmpty {
                if attempt < Self.maxCaptchaRetries {
                    await loginWithRetry(base: base, username: username, password: password, attempt: attempt + 1)
                    return
                }
                await MainActor.run {
                    self.loginError = "Could not solve captcha after \(Self.maxCaptchaRetries) attempts"
                    self.isLoggingIn = false
                }
                return
            }

            guard let url = URL(string: "\(base)/tmsapi/authenticate") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("application/json", forHTTPHeaderField: "Accept")

            let encodedPassword = Data(password.utf8).base64EncodedString()
            let body: [String: Any] = [
                "userName": username,
                "password": encodedPassword,
                "jwt": "",
                "otp": "",
                "captchaIdentifier": cid,
                "userCaptcha": solved
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: req)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let status = json?["status"] as? String ?? ""
            let message = json?["message"] as? String ?? "Unknown error"
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0

            if httpStatus == 200 || status == "200" {
                let dataObj = json?["data"] as? [String: Any]
                let jwt = dataObj?["jwt"] as? String ?? ""
                let sessionId = dataObj?["sessionId"] as? String ?? ""
                let sess = TMSSession(
                    brokerNumber: selectedBroker?.number ?? "",
                    jwt: jwt,
                    sessionId: sessionId,
                    userName: username,
                    savedAt: Date()
                )
                await MainActor.run {
                    self.session = sess
                    self.isLoggingIn = false
                }
            } else if status == "108" {
                if attempt < Self.maxCaptchaRetries {
                    await loginWithRetry(base: base, username: username, password: password, attempt: attempt + 1)
                } else {
                    await MainActor.run {
                        self.loginError = "Captcha failed after \(Self.maxCaptchaRetries) attempts. Please try again."
                        self.isLoggingIn = false
                    }
                }
            } else if message == "otpVerification" {
                await MainActor.run {
                    self.loginError = "2FA/OTP required — not yet supported"
                    self.isLoggingIn = false
                }
            } else {
                let readableError: String
                switch status {
                case "106": readableError = "Account disabled."
                case "210": readableError = "Password reset required. Login via browser first."
                default: readableError = message
                }
                await MainActor.run {
                    self.loginError = readableError
                    self.isLoggingIn = false
                }
            }
        } catch {
            await MainActor.run {
                self.loginError = error.localizedDescription
                self.isLoggingIn = false
            }
        }
    }

    private func fetchAndSolveCaptcha(base: String) async throws -> (id: String, solved: String) {
        guard let idURL = URL(string: "\(base)/tmsapi/captcha/id") else {
            throw URLError(.badURL)
        }
        let (idData, _) = try await URLSession.shared.data(from: idURL)
        guard let idJson = try JSONSerialization.jsonObject(with: idData) as? [String: Any],
              let cid = idJson["id"] as? String else {
            throw URLError(.cannotParseResponse)
        }

        guard let imgURL = URL(string: "\(base)/tmsapi/captcha/image/\(cid)") else {
            throw URLError(.badURL)
        }
        let (imgData, _) = try await URLSession.shared.data(from: imgURL)
        guard let img = NSImage(data: imgData) else {
            throw URLError(.cannotDecodeContentData)
        }

        let solved = solveCaptchaOCR(img)
        return (cid, solved)
    }

    func disconnect() {
        if let broker = selectedBroker, let sess = session {
            let base = broker.tmsBaseURL
            Task {
                guard let url = URL(string: "\(base)/tmsapi/authenticate/logout") else { return }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("Bearer \(sess.jwt)", forHTTPHeaderField: "Authorization")
                _ = try? await URLSession.shared.data(for: req)
            }
        }
        session = nil
    }

    func changeBroker() {
        disconnect()
        selectedBroker = nil
    }
}
