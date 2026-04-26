import SwiftUI

struct ForexPanel: View {
    @ObservedObject private var store = ForexStore.shared
    @State private var hoveredISO: String?

    private static let currencyFlags: [String: String] = [
        "INR": "🇮🇳", "USD": "🇺🇸", "EUR": "🇪🇺", "GBP": "🇬🇧",
        "CHF": "🇨🇭", "AUD": "🇦🇺", "CAD": "🇨🇦", "SGD": "🇸🇬",
        "JPY": "🇯🇵", "CNY": "🇨🇳", "SAR": "🇸🇦", "QAR": "🇶🇦",
        "THB": "🇹🇭", "AED": "🇦🇪", "MYR": "🇲🇾", "KRW": "🇰🇷",
        "SEK": "🇸🇪", "DKK": "🇩🇰", "HKD": "🇭🇰", "KWD": "🇰🇼",
        "BHD": "🇧🇭", "OMR": "🇴🇲",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("विनिमय दर")
                        .font(.system(size: 13, weight: .semibold))
                    if !store.lastUpdated.isEmpty {
                        Text(store.lastUpdated)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Button {
                    store.fetch()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .medium))
                        .rotationEffect(.degrees(store.isLoading ? 360 : 0))
                        .animation(store.isLoading
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : .default, value: store.isLoading)
                }
                .buttonStyle(.borderless)
                .disabled(store.isLoading)
                .help("Refresh rates")
            }

            if store.isLoading && store.rates.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading rates…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else if let error = store.error, store.rates.isEmpty {
                Spacer()
                VStack(spacing: 6) {
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
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                rateHeader
                    .padding(.bottom, 2)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(Array(store.rates.enumerated()), id: \.element.id) { idx, rate in
                            rateRow(rate, isEven: idx.isMultiple(of: 2))
                        }
                    }
                }
            }
        }
    }

    private var rateHeader: some View {
        HStack(spacing: 0) {
            Text("CURRENCY")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("BUY")
                .frame(width: 64, alignment: .trailing)
            Text("SELL")
                .frame(width: 64, alignment: .trailing)
        }
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 8)
    }

    private func rateRow(_ rate: ForexRate, isEven: Bool) -> some View {
        let isHovered = hoveredISO == rate.iso3
        let flag = Self.currencyFlags[rate.iso3] ?? "💱"

        return HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(flag)
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 0) {
                    Text(rate.iso3)
                        .font(.system(size: 11, weight: .semibold))
                    Text(rate.unit > 1 ? "\(rate.unit) \(rate.name)" : rate.name)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(rate.buy)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 64, alignment: .trailing)

            Text(rate.sell)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isHovered
                    ? Color.accentColor.opacity(0.12)
                    : (isEven ? Color.secondary.opacity(0.04) : Color.clear))
        )
        .onHover { hovering in
            hoveredISO = hovering ? rate.iso3 : nil
        }
        .help("\(rate.name) — Buy: \(rate.buy) / Sell: \(rate.sell) NPR per \(rate.unit) \(rate.iso3)")
    }
}
