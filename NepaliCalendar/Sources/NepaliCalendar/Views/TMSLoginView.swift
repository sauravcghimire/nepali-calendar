import SwiftUI

struct TMSLoginView: View {
    @ObservedObject private var tms = TMSStore.shared
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if tms.isConnected {
                connectedView
            } else if tms.selectedBroker != nil {
                loginFormView
            } else {
                brokerListView
            }
        }
        .frame(width: 380, height: 440)
        .onAppear {
            if tms.brokers.isEmpty && tms.selectedBroker == nil {
                tms.fetchBrokers()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 1) {
                Text("TMS Connect")
                    .font(.system(size: 14, weight: .bold))
                if let broker = tms.selectedBroker {
                    Text("Broker #\(broker.number) — \(broker.name)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Select your broker to connect")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.indigo.opacity(0.05))
    }

    // MARK: - Connected

    private var connectedView: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.green)
            }
            Text("Connected to TMS")
                .font(.system(size: 15, weight: .bold))
            if let sess = tms.session {
                VStack(spacing: 4) {
                    infoRow(label: "User", value: sess.userName)
                    infoRow(label: "Broker", value: "#\(sess.brokerNumber)")
                    infoRow(label: "Since", value: Self.timeFmt.string(from: sess.savedAt))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.15)))
                .padding(.horizontal, 20)
            }
            HStack(spacing: 12) {
                Button {
                    tms.disconnect()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 10))
                        Text("Disconnect")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.red.opacity(0.1)))
                }
                .buttonStyle(.plain)

                Button {
                    tms.changeBroker()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                        Text("Change Broker")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.indigo.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
        }
    }

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    // MARK: - Broker List

    private var brokerListView: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                TextField("Search broker…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
            .padding(8)

            if tms.isLoadingBrokers {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(0..<10, id: \.self) { _ in
                            skeletonBrokerRow
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            } else if let err = tms.brokerError {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    Text(err)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { tms.fetchBrokers() }
                        .controlSize(.small)
                }
                .padding()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredBrokers) { broker in
                            brokerRow(broker)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private var skeletonBrokerRow: some View {
        HStack(spacing: 8) {
            SkeletonBox(width: 32, height: 32, radius: 6)
            VStack(alignment: .leading, spacing: 4) {
                SkeletonBox(width: .random(in: 120...220), height: 10)
                SkeletonBox(width: .random(in: 80...150), height: 8)
            }
            Spacer()
            SkeletonBox(width: 9, height: 9, radius: 2)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.04)))
    }

    private var filteredBrokers: [Broker] {
        if searchText.isEmpty { return tms.brokers }
        return tms.brokers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.number.contains(searchText)
        }
    }

    private func brokerRow(_ broker: Broker) -> some View {
        Button {
            tms.selectedBroker = broker
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.indigo.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Text(broker.number)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.indigo)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(broker.name)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Text(broker.address)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if broker.tmsLink != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green.opacity(0.6))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.04)))
    }

    // MARK: - Login Form

    private var loginFormView: some View {
        TMSLoginFormView()
    }
}

// MARK: - Login Form (separate struct for state isolation)

private struct TMSLoginFormView: View {
    @ObservedObject private var tms = TMSStore.shared
    @State private var username = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    enum Field { case username, password }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        Button {
                            tms.changeBroker()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Change Broker")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(.indigo)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.bottom, 4)

                    if let broker = tms.selectedBroker {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.green)
                            Text(broker.tmsBaseURL.replacingOccurrences(of: "https://", with: ""))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.green.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.green.opacity(0.15), lineWidth: 1)
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Client Code / Username")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("Enter client code", text: $username)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.06)))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.15)))
                            .focused($focusedField, equals: .username)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        SecureField("Enter password", text: $password)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.06)))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.15)))
                            .focused($focusedField, equals: .password)
                    }

                    if let err = tms.loginError {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 10))
                            Text(err)
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.red)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.red.opacity(0.06))
                        )
                    }

                    Button {
                        tms.login(username: username, password: password)
                    } label: {
                        HStack(spacing: 6) {
                            if tms.isLoggingIn {
                                ProgressView()
                                    .controlSize(.mini)
                                    .tint(.white)
                            }
                            Image(systemName: "lock.open.fill")
                                .font(.system(size: 11))
                            Text(tms.isLoggingIn ? "Connecting…" : "Connect to TMS")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(canLogin
                                    ? LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canLogin || tms.isLoggingIn)

                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                        Text("Credentials are sent securely via HTTPS directly to your broker's TMS")
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(.tertiary)
                }
                .padding(14)
            }
        }
        .onAppear {
            focusedField = .username
        }
        .onSubmit {
            switch focusedField {
            case .username: focusedField = .password
            case .password:
                if canLogin { tms.login(username: username, password: password) }
            case .none: break
            }
        }
    }

    private var canLogin: Bool {
        !username.isEmpty && !password.isEmpty
    }
}
