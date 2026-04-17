import SwiftUI

/// Horizontal scrolling row of the twelve signs. Tapping a sign expands its
/// prediction text below the row. Long-press (or the ⓘ control) sets the
/// default sign so it's pre-selected on next launch.
struct HoroscopeRow: View {
    let bsYear: Int
    let bsMonth: Int
    let bsDay: Int

    @EnvironmentObject var settings: Settings
    @State private var selected: ZodiacSign? = nil

    var body: some View {
        let predictions = RashifalStore.predictions(bsYear: bsYear,
                                                    bsMonth: bsMonth,
                                                    bsDay: bsDay)
        let resolvedSelection = selected ?? settings.defaultSign ?? ZodiacSign.mesh

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("राशिफल")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if let def = settings.defaultSign {
                    Text("Default: \(def.nepaliName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(predictions, id: \.sign) { item in
                        SignChip(sign: item.sign,
                                 isSelected: item.sign == resolvedSelection,
                                 isDefault: settings.defaultSign == item.sign,
                                 onTap: { selected = item.sign },
                                 onSetDefault: { settings.defaultSign = item.sign })
                    }
                }
                .padding(.vertical, 2)
            }

            PredictionBlock(sign: resolvedSelection,
                            text: predictions.first(where: { $0.sign == resolvedSelection })?.text ?? "",
                            isDefault: settings.defaultSign == resolvedSelection,
                            onSetDefault: { settings.defaultSign = resolvedSelection },
                            onClearDefault: { settings.defaultSign = nil })
        }
    }
}

private struct SignChip: View {
    let sign: ZodiacSign
    let isSelected: Bool
    let isDefault: Bool
    let onTap: () -> Void
    let onSetDefault: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    Text(sign.symbol)
                        .font(.system(size: 20))
                    if isDefault {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.yellow)
                            .offset(x: 5, y: -3)
                    }
                }
                Text(sign.nepaliName)
                    .font(.system(size: 10))
            }
            .frame(width: 54, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected
                          ? Color.accentColor.opacity(0.22)
                          : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(isDefault ? "Remove as default" : "Set as default sign") {
                onSetDefault()
            }
        }
        .help("\(sign.nepaliName) • \(sign.englishName) — right-click to set default")
    }
}

private struct PredictionBlock: View {
    let sign: ZodiacSign
    let text: String
    let isDefault: Bool
    let onSetDefault: () -> Void
    let onClearDefault: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(sign.symbol).font(.system(size: 16))
                Text("\(sign.nepaliName) (\(sign.englishName))")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button(action: isDefault ? onClearDefault : onSetDefault) {
                    Label(isDefault ? "Unset default" : "Set as default",
                          systemImage: isDefault ? "star.slash" : "star")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            Text(text.isEmpty ? "No prediction available for this date." : text)
                .font(.system(size: 12))
                .foregroundStyle(text.isEmpty ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.06))
        )
    }
}
