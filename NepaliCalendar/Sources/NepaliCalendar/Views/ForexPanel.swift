import SwiftUI

struct ForexPanel: View {
    @ObservedObject private var store = ForexStore.shared
    @ObservedObject private var settings = Settings.shared
    @State private var hoveredISO: String?
    @State private var showPicker = false

    private static let currencyFlags: [String: String] = [
        "INR": "🇮🇳", "USD": "🇺🇸", "EUR": "🇪🇺", "GBP": "🇬🇧",
        "CHF": "🇨🇭", "AUD": "🇦🇺", "CAD": "🇨🇦", "SGD": "🇸🇬",
        "JPY": "🇯🇵", "CNY": "🇨🇳", "SAR": "🇸🇦", "QAR": "🇶🇦",
        "THB": "🇹🇭", "AED": "🇦🇪", "MYR": "🇲🇾", "KRW": "🇰🇷",
        "SEK": "🇸🇪", "DKK": "🇩🇰", "HKD": "🇭🇰", "KWD": "🇰🇼",
        "BHD": "🇧🇭", "OMR": "🇴🇲",
    ]

    private static let currencyColors: [String: Color] = [
        "USD": .green, "EUR": .blue, "GBP": .purple, "JPY": .red,
        "AUD": .orange, "CAD": .red, "INR": .orange, "CNY": .red,
        "CHF": .red, "SGD": .pink, "AED": .green, "SAR": .green,
        "KRW": .blue, "THB": .indigo, "MYR": .yellow, "QAR": .purple,
        "SEK": .blue, "DKK": .red, "HKD": .red, "KWD": .green,
        "BHD": .red, "OMR": .red,
    ]

    private var visibleRates: [ForexRate] {
        store.rates.filter { settings.isCurrencySelected($0.iso3) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow

            if store.isLoading && store.rates.isEmpty {
                loadingView
            } else if let error = store.error, store.rates.isEmpty {
                errorView(error)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(visibleRates) { rate in
                            rateCard(rate)
                        }
                    }
                }

                if visibleRates.isEmpty && !store.rates.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "plus.circle.dashed")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("No currencies selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Tap + to add currencies")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }

                HStack {
                    Text("\(visibleRates.count) of \(store.rates.count) currencies")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 26, height: 26)
                    Image(systemName: "dollarsign.arrow.circlepath")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.green)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("विनिमय दर")
                        .font(.system(size: 13, weight: .semibold))
                    if !store.lastUpdated.isEmpty {
                        Text(store.lastUpdated)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()

            Button { showPicker.toggle() } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .help("Add/remove currencies")
            .popover(isPresented: $showPicker, arrowEdge: .leading) {
                currencyPicker
            }

            Button { store.fetch() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
                    .rotationEffect(.degrees(store.isLoading ? 360 : 0))
                    .animation(store.isLoading
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .default, value: store.isLoading)
            }
            .buttonStyle(.borderless)
            .disabled(store.isLoading)
        }
    }

    // MARK: - Rate Card

    private func rateCard(_ rate: ForexRate) -> some View {
        let isHovered = hoveredISO == rate.iso3
        let flag = Self.currencyFlags[rate.iso3] ?? "💱"
        let accent = Self.currencyColors[rate.iso3] ?? .blue

        return VStack(spacing: 0) {
            // Top: flag + name + remove
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(accent.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Text(flag)
                        .font(.system(size: 18))
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(rate.iso3)
                            .font(.system(size: 13, weight: .bold))
                        if rate.unit > 1 {
                            Text("×\(rate.unit)")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(Color.secondary.opacity(0.1))
                                )
                        }
                    }
                    Text(rate.name)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button { settings.toggleCurrency(rate.iso3) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help("Remove \(rate.iso3)")
            }

            // Buy / Sell
            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text("BUY")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.tertiary)
                    Text(rate.buy)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.green.opacity(0.06))
                )

                VStack(spacing: 2) {
                    Text("SELL")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.tertiary)
                    Text(rate.sell)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red.opacity(0.06))
                )
            }
            .padding(.top, 8)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered
                    ? accent.opacity(0.08)
                    : accent.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accent.opacity(isHovered ? 0.2 : 0.08), lineWidth: 1)
        )
        .onHover { hoveredISO = $0 ? rate.iso3 : nil }
    }

    // MARK: - Currency Picker

    private var currencyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Select Currencies")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button("Reset") {
                    settings.selectedCurrencies = Settings.defaultCurrencies
                }
                .font(.system(size: 10))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 2) {
                    ForEach(store.rates) { rate in
                        let selected = settings.isCurrencySelected(rate.iso3)
                        let flag = Self.currencyFlags[rate.iso3] ?? "💱"

                        Button { settings.toggleCurrency(rate.iso3) } label: {
                            HStack(spacing: 8) {
                                Text(flag).font(.system(size: 14))
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(rate.iso3)
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(rate.name)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 13))
                                    .foregroundStyle(selected ? .green : .secondary.opacity(0.3))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selected ? Color.green.opacity(0.06) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding(12)
        .frame(width: 240)
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack(spacing: 8) {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading rates…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Spacer()
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Could not load rates")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(error)
                .font(.system(size: 9))
                .foregroundStyle(.red.opacity(0.8))
                .multilineTextAlignment(.center)
            Button("Retry") { store.fetch() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
