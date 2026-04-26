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

    private static let bsMonthNames = [
        "बैशाख", "जेठ", "असार", "साउन", "भदौ", "असोज",
        "कार्तिक", "मंसिर", "पुष", "माघ", "फाल्गुन", "चैत",
    ]
    private static let adMonthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("मिति रूपान्तरण")
                    .font(.system(size: 13, weight: .semibold))
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
                // Year
                VStack(alignment: .leading, spacing: 2) {
                    Text("Year")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField(mode == .bsToAD ? "2082" : "2025", text: $yearText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .frame(width: 64)
                        .onChange(of: yearText) { _ in clearResult() }
                }

                // Month
                VStack(alignment: .leading, spacing: 2) {
                    Text("Month")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $monthSelection) {
                        ForEach(1...12, id: \.self) { m in
                            Text(monthLabel(m)).tag(m)
                        }
                    }
                    .frame(width: 110)
                    .onChange(of: monthSelection) { _ in clearResult() }
                }

                // Day
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("15", text: $dayText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .frame(width: 44)
                        .onChange(of: dayText) { _ in clearResult() }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(" ")
                        .font(.system(size: 9))
                    Button(action: convert) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.borderless)
                    .help("Convert")
                }
            }

            if let result {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 12))
                    Text(result)
                        .font(.system(size: 12, weight: .medium))
                        .textSelection(.enabled)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.green.opacity(0.08))
                )
            } else if let errorMsg {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 12))
                    Text(errorMsg)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange.opacity(0.08))
                )
            }
        }
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
