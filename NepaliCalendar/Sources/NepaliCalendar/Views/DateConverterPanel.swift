import SwiftUI

struct DateConverterPanel: View {
    enum Mode: String, CaseIterable {
        case bsToAD = "BS → AD"
        case adToBS = "AD → BS"
    }

    @State private var mode: Mode = .bsToAD
    @State private var yearText = ""
    @State private var monthSelection = 1
    @State private var dayText = ""
    @State private var result: String?
    @State private var errorMsg: String?
    @State private var isHovering = false

    private static let bsMonthNames = [
        "बैशाख", "जेठ", "असार", "साउन", "भदौ", "असोज",
        "कार्तिक", "मंसिर", "पुष", "माघ", "फाल्गुन", "चैत",
    ]
    private static let adMonthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.indigo)
                    Text("मिति रूपान्तरण")
                        .font(.system(size: 13, weight: .semibold))
                }
                Spacer()
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                .onChange(of: mode) { _ in clearResult() }
            }

            HStack(spacing: 8) {
                inputField(label: "Year",
                           placeholder: mode == .bsToAD ? "2082" : "2025",
                           text: $yearText,
                           width: 68)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Month")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Picker("", selection: $monthSelection) {
                        ForEach(1...12, id: \.self) { m in
                            Text(monthLabel(m)).tag(m)
                        }
                    }
                    .frame(width: 120)
                    .onChange(of: monthSelection) { _ in clearResult() }
                }

                inputField(label: "Day",
                           placeholder: "15",
                           text: $dayText,
                           width: 50)

                VStack(alignment: .leading, spacing: 3) {
                    Text(" ").font(.system(size: 9))
                    Button(action: convert) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.indigo)
                            .scaleEffect(isHovering ? 1.15 : 1.0)
                            .animation(.easeInOut(duration: 0.15), value: isHovering)
                    }
                    .buttonStyle(.borderless)
                    .onHover { isHovering = $0 }
                    .help("Convert")
                }
            }

            if let result {
                resultCard(text: result, isError: false)
            } else if let errorMsg {
                resultCard(text: errorMsg, isError: true)
            }
        }
    }

    private func inputField(label: String, placeholder: String,
                            text: Binding<String>, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
                .frame(width: width)
                .onChange(of: text.wrappedValue) { _ in clearResult() }
        }
    }

    private func resultCard(text: String, isError: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                .font(.system(size: 14))
                .foregroundStyle(isError ? .orange : .green)

            if isError {
                Text(text)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text(text)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isError
                      ? Color.orange.opacity(0.06)
                      : Color.green.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isError
                        ? Color.orange.opacity(0.15)
                        : Color.green.opacity(0.15),
                        lineWidth: 1)
        )
    }

    private func monthLabel(_ m: Int) -> String {
        if mode == .bsToAD {
            return "\(m) - \(Self.bsMonthNames[m - 1])"
        } else {
            return "\(m) - \(Self.adMonthNames[m - 1])"
        }
    }

    private func clearResult() {
        result = nil
        errorMsg = nil
    }

    private func convert() {
        guard let year = Int(yearText), year > 0 else {
            errorMsg = "Enter a valid year"
            result = nil
            return
        }
        guard let day = Int(dayText), day > 0 else {
            errorMsg = "Enter a valid day"
            result = nil
            return
        }

        switch mode {
        case .bsToAD:
            guard DateConverter.supportedBSRange.contains(year) else {
                errorMsg = "BS year must be between 2000–2100"
                result = nil
                return
            }
            if let maxDay = DateConverter.daysInBSMonth(year: year, month: monthSelection),
               day > maxDay {
                errorMsg = "Max \(maxDay) days in \(Self.bsMonthNames[monthSelection - 1]) \(year)"
                result = nil
                return
            }
            if let ad = DateConverter.bsToAD(year: year, month: monthSelection, day: day) {
                let monthName = Self.adMonthNames[ad.month - 1]
                result = "\(monthName) \(ad.day), \(ad.year) AD"
            } else {
                errorMsg = "Conversion failed"
                result = nil
            }

        case .adToBS:
            if let bs = DateConverter.adToBS(year: year, month: monthSelection, day: day) {
                let monthName = Self.bsMonthNames[bs.month - 1]
                let nepYear = NepaliNumerals.devanagari(bs.year)
                let nepDay = NepaliNumerals.devanagari(bs.day)
                result = "\(nepDay) \(monthName), \(nepYear) BS  (\(bs.year)-\(String(format: "%02d", bs.month))-\(String(format: "%02d", bs.day)))"
            } else {
                errorMsg = "Date outside supported range (BS 2000–2100)"
                result = nil
            }
        }
    }
}
