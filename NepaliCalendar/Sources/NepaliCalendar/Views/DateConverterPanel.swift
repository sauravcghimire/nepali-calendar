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
    @State private var resultDetail: String?
    @State private var errorMsg: String?
    @State private var convertHover = false
    @State private var swapHover = false
    @State private var todayHover = false
    @State private var showResult = false

    private static let bsMonthNames = [
        "बैशाख", "जेठ", "असार", "साउन", "भदौ", "असोज",
        "कार्तिक", "मंसिर", "पुष", "माघ", "फाल्गुन", "चैत",
    ]
    private static let adMonthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]

    private var modeColor: Color { mode == .bsToAD ? .indigo : .teal }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(modeColor.opacity(0.15))
                            .frame(width: 26, height: 26)
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(modeColor)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text("मिति रूपान्तरण")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Date Converter")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Mode toggle pills
                HStack(spacing: 0) {
                    ForEach(Mode.allCases, id: \.self) { m in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { mode = m }
                            clearResult()
                        } label: {
                            Text(m.rawValue)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(mode == m ? .white : .secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule().fill(mode == m ? modeColor : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Capsule().fill(Color.secondary.opacity(0.08)))
            }
            .padding(.bottom, 10)

            // Input row
            HStack(spacing: 6) {
                // Year
                VStack(alignment: .leading, spacing: 3) {
                    Label("YEAR", systemImage: "calendar")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                    TextField(mode == .bsToAD ? "2082" : "2025", text: $yearText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(modeColor.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(modeColor.opacity(0.2), lineWidth: 1)
                        )
                        .frame(width: 70)
                        .onChange(of: yearText) { _ in clearResult() }
                }

                // Month
                VStack(alignment: .leading, spacing: 3) {
                    Label("MONTH", systemImage: "list.bullet")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $monthSelection) {
                        ForEach(1...12, id: \.self) { m in
                            Text(monthLabel(m)).tag(m)
                        }
                    }
                    .frame(width: 130)
                    .onChange(of: monthSelection) { _ in clearResult() }
                }

                // Day
                VStack(alignment: .leading, spacing: 3) {
                    Label("DAY", systemImage: "number")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                    TextField("15", text: $dayText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(modeColor.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(modeColor.opacity(0.2), lineWidth: 1)
                        )
                        .frame(width: 52)
                        .onChange(of: dayText) { _ in clearResult() }
                }

                Spacer(minLength: 4)

                // Action buttons
                VStack(alignment: .leading, spacing: 3) {
                    Text(" ").font(.system(size: 8))
                    HStack(spacing: 4) {
                        // Today button
                        Button(action: fillToday) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(todayHover ? modeColor : .secondary)
                                .frame(width: 28, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(todayHover ? modeColor.opacity(0.1) : Color.secondary.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                        .onHover { todayHover = $0 }
                        .help("Fill today's date")

                        // Swap button
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                mode = mode == .bsToAD ? .adToBS : .bsToAD
                            }
                            clearResult()
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(swapHover ? modeColor : .secondary)
                                .frame(width: 28, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(swapHover ? modeColor.opacity(0.1) : Color.secondary.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                        .onHover { swapHover = $0 }
                        .help("Swap mode")

                        // Convert button
                        Button(action: convert) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(
                                            LinearGradient(
                                                colors: [modeColor, modeColor.opacity(0.7)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing)
                                        )
                                )
                                .scaleEffect(convertHover ? 1.08 : 1.0)
                                .animation(.easeInOut(duration: 0.15), value: convertHover)
                        }
                        .buttonStyle(.plain)
                        .onHover { convertHover = $0 }
                        .help("Convert")
                    }
                }
            }
            .padding(.bottom, 8)

            // Result / Error
            if showResult, let result {
                resultCard(isError: false)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let errorMsg {
                errorCard(errorMsg)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Result

    private func resultCard(isError: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(result ?? "")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .textSelection(.enabled)
                if let resultDetail {
                    Text(resultDetail)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Copy button
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result ?? "", forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.06), Color.green.opacity(0.02)],
                        startPoint: .leading, endPoint: .trailing)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.green.opacity(0.18), lineWidth: 1)
        )
    }

    private func errorCard(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.orange)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.orange.opacity(0.9))
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func monthLabel(_ m: Int) -> String {
        if mode == .bsToAD {
            return "\(m) - \(Self.bsMonthNames[m - 1])"
        } else {
            return "\(m) - \(Self.adMonthNames[m - 1])"
        }
    }

    private func fillToday() {
        clearResult()
        if mode == .bsToAD {
            if let bs = CalendarStore.shared.bsDate(forAD: Date()) {
                yearText = "\(bs.bsYear)"
                monthSelection = bs.bsMonth
                dayText = "\(bs.bsDay)"
            }
        } else {
            let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            yearText = "\(comps.year ?? 2025)"
            monthSelection = comps.month ?? 1
            dayText = "\(comps.day ?? 1)"
        }
    }

    private func clearResult() {
        withAnimation(.easeOut(duration: 0.15)) { showResult = false }
        result = nil
        resultDetail = nil
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
                let bsMonthName = Self.bsMonthNames[monthSelection - 1]
                resultDetail = "\(NepaliNumerals.devanagari(day)) \(bsMonthName), \(NepaliNumerals.devanagari(year)) BS"
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showResult = true }
            } else {
                errorMsg = "Conversion failed"
                result = nil
            }

        case .adToBS:
            if let bs = DateConverter.adToBS(year: year, month: monthSelection, day: day) {
                let monthName = Self.bsMonthNames[bs.month - 1]
                let nepYear = NepaliNumerals.devanagari(bs.year)
                let nepDay = NepaliNumerals.devanagari(bs.day)
                result = "\(nepDay) \(monthName), \(nepYear) BS"
                resultDetail = "\(bs.year)-\(String(format: "%02d", bs.month))-\(String(format: "%02d", bs.day)) • \(Self.adMonthNames[monthSelection - 1]) \(day), \(year) AD"
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showResult = true }
            } else {
                errorMsg = "Date outside supported range (BS 2000–2100)"
                result = nil
            }
        }
    }
}
