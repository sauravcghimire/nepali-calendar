import SwiftUI

/// Popover for jumping directly to a (bsYear, bsMonth).
struct MonthYearPicker: View {
    let availableYears: [Int]
    @Binding var bsYear: Int
    @Binding var bsMonth: Int
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Jump to month")
                .font(.headline)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Year").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $bsYear) {
                        ForEach(availableYears, id: \.self) { y in
                            Text("\(NepaliNumerals.devanagari(y))  (\(y))").tag(y)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Month").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $bsMonth) {
                        ForEach(1...12, id: \.self) { m in
                            Text(NepaliMonth.name(m)).tag(m)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
            }

            HStack {
                Spacer()
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 340)
    }
}
