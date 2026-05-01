import SwiftUI

struct StockPanel: View {
    @ObservedObject private var store = StockStore.shared
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var alertStore = StockAlertStore.shared
    @State private var searchText = ""
    @State private var hoveredSymbol: String?
    @State private var sortKey: SortKey = .symbol
    @State private var sortAscending = true
    @State private var alertSymbol: String?

    enum SortKey: String {
        case symbol, ltp, change, percent, volume
    }

    private var filteredStocks: [StockQuote] {
        let base = searchText.isEmpty
            ? store.stocks
            : store.stocks.filter { $0.symbol.localizedCaseInsensitiveContains(searchText) }

        let sorted = base.sorted { a, b in
            let result: Bool
            switch sortKey {
            case .symbol:  result = a.symbol < b.symbol
            case .ltp:     result = a.ltp < b.ltp
            case .change:  result = a.pointChange < b.pointChange
            case .percent: result = a.percentChange < b.percentChange
            case .volume:  result = a.volume < b.volume
            }
            return sortAscending ? result : !result
        }

        let favs = sorted.filter { settings.isStockFavorite($0.symbol) }
        let rest = sorted.filter { !settings.isStockFavorite($0.symbol) }
        return favs + rest
    }

    private var gainers: Int { store.stocks.filter { $0.pointChange > 0 }.count }
    private var losers: Int { store.stocks.filter { $0.pointChange < 0 }.count }
    private var unchanged: Int { store.stocks.filter { $0.pointChange == 0 }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerRow.padding(.bottom, 6)

            // Summary chips
            if !store.stocks.isEmpty {
                summaryBar.padding(.bottom, 6)
            }

            // Search
            searchBar.padding(.bottom, 6)

            if store.isLoading && store.stocks.isEmpty {
                loadingView
            } else if let error = store.error, store.stocks.isEmpty {
                errorView(error)
            } else {
                // Column headers + list + status — no extra gaps
                columnHeader.padding(.bottom, 4)
                stockList
                statusBar.padding(.top, 4)
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 1) {
                    Text("शेयर बजार")
                        .font(.system(size: 13, weight: .semibold))
                    if let last = store.lastFetched {
                        Text("Updated \(last, style: .time)")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
            if store.isLoading {
                ProgressView()
                    .controlSize(.mini)
            }
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
        }
    }

    // MARK: - Summary

    private var summaryBar: some View {
        HStack(spacing: 6) {
            summaryChip(icon: "arrow.up.circle.fill", count: gainers, color: .green, label: "Up")
            summaryChip(icon: "arrow.down.circle.fill", count: losers, color: .red, label: "Down")
            summaryChip(icon: "minus.circle.fill", count: unchanged, color: .secondary, label: "Flat")
            Spacer()
            if !store.isMarketDay {
                HStack(spacing: 3) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 9))
                    Text("CLOSED")
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.orange.opacity(0.12)))
            }
        }
    }

    private func summaryChip(icon: String, count: Int, color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)
            Text("\(count)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.08)))
        .help("\(count) \(label)")
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            TextField("Search symbol…", text: $searchText)
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
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
    }

    // MARK: - Column Header

    private var columnHeader: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 20)
            sortButton("SYMBOL", key: .symbol, alignment: .leading)
            sortButton("LTP", key: .ltp, alignment: .trailing)
            sortButton("CHG", key: .change, alignment: .trailing)
            sortButton("%", key: .percent, alignment: .trailing)
            sortButton("VOL", key: .volume, alignment: .trailing)
        }
        .padding(.horizontal, 4)
    }

    private func sortButton(_ label: String, key: SortKey, alignment: Alignment) -> some View {
        Button {
            if sortKey == key { sortAscending.toggle() }
            else { sortKey = key; sortAscending = key == .symbol }
        } label: {
            HStack(spacing: 2) {
                if alignment == .trailing { Spacer() }
                Text(label)
                if sortKey == key {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 6))
                }
                if alignment == .leading { Spacer() }
            }
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(sortKey == key ? .primary : .tertiary)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stock List

    private var favoriteStocks: [StockQuote] {
        filteredStocks.filter { settings.isStockFavorite($0.symbol) }
    }

    private var regularStocks: [StockQuote] {
        filteredStocks.filter { !settings.isStockFavorite($0.symbol) }
    }

    private var stockList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 2) {
                if !favoriteStocks.isEmpty {
                    ForEach(favoriteStocks) { stock in
                        favoriteCard(stock)
                    }
                    if !regularStocks.isEmpty {
                        Divider().padding(.vertical, 4)
                    }
                }
                ForEach(Array(regularStocks.enumerated()), id: \.element.id) { idx, stock in
                    stockRow(stock, isEven: idx.isMultiple(of: 2))
                }
            }
        }
    }

    // MARK: - Favorite Card

    private func favoriteCard(_ stock: StockQuote) -> some View {
        let isHovered = hoveredSymbol == stock.symbol
        let dir = stock.direction
        let color = directionColor(dir)
        let hasAlert = alertStore.hasAlert(for: stock.symbol)

        return VStack(alignment: .leading, spacing: 0) {
            // Top row: symbol + LTP
            HStack(alignment: .top) {
                HStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(color.opacity(0.15))
                            .frame(width: 28, height: 28)
                        Text(String(stock.symbol.prefix(2)))
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(color)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(stock.symbol)
                                .font(.system(size: 13, weight: .bold))
                            if hasAlert {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.orange)
                            }
                        }
                        HStack(spacing: 3) {
                            Circle().fill(color).frame(width: 5, height: 5)
                            Text(dir == .up ? "Gaining" : dir == .down ? "Losing" : "Unchanged")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Rs \(formatPrice(stock.ltp))")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                    changePill(stock)
                }
            }

            // Stats grid
            HStack(spacing: 0) {
                statCell(label: "Change", value: formatChange(stock.pointChange), color: color)
                statCell(label: "% Change", value: formatChange(stock.percentChange) + "%", color: color)
                statCell(label: "Volume", value: formatVolume(stock.volume), color: .secondary)
                statCell(label: "Prev Close", value: formatPrice(stock.prevClose), color: .secondary)
            }
            .padding(.top, 8)

            // OHLC bar
            HStack(spacing: 0) {
                ohlcCell(label: "Open", value: stock.open)
                ohlcCell(label: "High", value: stock.high)
                ohlcCell(label: "Low", value: stock.low)
            }
            .padding(.top, 6)

            // Action row
            HStack(spacing: 8) {
                Button { settings.toggleFavoriteStock(stock.symbol) } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "star.slash.fill")
                            .font(.system(size: 8))
                        Text("Unfavorite")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(.yellow)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.top, 8)
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture { alertSymbol = stock.symbol }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(isHovered ? 0.10 : 0.06),
                                 color.opacity(isHovered ? 0.04 : 0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
        .onHover { hoveredSymbol = $0 ? stock.symbol : nil }
        .popover(isPresented: Binding(
            get: { alertSymbol == stock.symbol },
            set: { if !$0 { alertSymbol = nil } }
        ), arrowEdge: .trailing) {
            StockAlertPopover(stock: stock) { alertSymbol = nil }
        }
    }

    private func statCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func ohlcCell(label: String, value: Double) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(formatPrice(value))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Regular Row

    private func stockRow(_ stock: StockQuote, isEven: Bool) -> some View {
        let isHovered = hoveredSymbol == stock.symbol
        let dir = stock.direction
        let hasAlert = alertStore.hasAlert(for: stock.symbol)

        return HStack(spacing: 0) {
            Button { settings.toggleFavoriteStock(stock.symbol) } label: {
                Image(systemName: "star")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary.opacity(0.25))
            }
            .buttonStyle(.plain)
            .frame(width: 20)

            HStack(spacing: 4) {
                Circle()
                    .fill(directionColor(dir))
                    .frame(width: 5, height: 5)
                Text(stock.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                if hasAlert {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.orange)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)

            Text(formatPrice(stock.ltp))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .trailing)

            changePill(stock)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(formatChange(stock.percentChange) + "%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(directionColor(dir))
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(formatVolume(stock.volume))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture { alertSymbol = stock.symbol }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered
                    ? Color.accentColor.opacity(0.10)
                    : (isEven ? Color.secondary.opacity(0.03) : Color.clear))
        )
        .onHover { hoveredSymbol = $0 ? stock.symbol : nil }
        .popover(isPresented: Binding(
            get: { alertSymbol == stock.symbol },
            set: { if !$0 { alertSymbol = nil } }
        ), arrowEdge: .trailing) {
            StockAlertPopover(stock: stock) { alertSymbol = nil }
        }
    }

    private func changePill(_ stock: StockQuote) -> some View {
        let dir = stock.direction
        let color = directionColor(dir)

        return HStack(spacing: 2) {
            if dir == .up {
                Image(systemName: "triangleshape.fill").font(.system(size: 5))
            } else if dir == .down {
                Image(systemName: "triangleshape.fill").font(.system(size: 5))
                    .rotationEffect(.degrees(180))
            }
            Text(formatChange(stock.pointChange))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
        }
        .foregroundColor(dir == .unchanged ? Color.secondary : Color.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule().fill(dir == .unchanged
                ? Color.secondary.opacity(0.12)
                : color.opacity(0.85))
        )
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 4) {
            Text("\(filteredStocks.count) stocks")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            if !settings.favoriteStocks.isEmpty {
                Text("• \(settings.favoriteStocks.count) fav")
                    .font(.system(size: 9))
                    .foregroundStyle(.yellow.opacity(0.8))
            }
            Spacer()
        }
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack(spacing: 2) {
            ForEach(0..<8, id: \.self) { i in
                skeletonStockRow(isEven: i.isMultiple(of: 2))
            }
        }
    }

    private func skeletonStockRow(isEven: Bool) -> some View {
        HStack(spacing: 0) {
            SkeletonBox(width: 12, height: 12).frame(width: 20)
            HStack(spacing: 4) {
                SkeletonBox(width: 5, height: 5, radius: 2.5)
                SkeletonBox(width: .random(in: 40...70), height: 10)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            SkeletonBox(width: 55, height: 10).frame(maxWidth: .infinity, alignment: .trailing)
            SkeletonBox(width: 40, height: 16, radius: 8).frame(maxWidth: .infinity, alignment: .trailing)
            SkeletonBox(width: 35, height: 10).frame(maxWidth: .infinity, alignment: .trailing)
            SkeletonBox(width: 30, height: 10).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isEven ? Color.secondary.opacity(0.03) : Color.clear)
        )
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "chart.line.downtrend.xyaxis").font(.title3).foregroundStyle(.secondary)
            Text("Could not load data").font(.caption).foregroundStyle(.secondary)
            Text(error).font(.system(size: 9)).foregroundStyle(.red.opacity(0.8)).multilineTextAlignment(.center)
            Button("Retry") { store.fetch() }.buttonStyle(.bordered).controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Formatting

    private func directionColor(_ dir: StockQuote.Direction) -> Color {
        switch dir {
        case .up:        return .green
        case .down:      return .red
        case .unchanged: return .secondary
        }
    }

    private func formatPrice(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func formatChange(_ value: Double) -> String {
        if value > 0 { return String(format: "+%.2f", value) }
        return String(format: "%.2f", value)
    }

    private func formatVolume(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", value / 1_000) }
        return String(format: "%.0f", value)
    }
}

// MARK: - Alert Popover

private struct StockAlertPopover: View {
    let stock: StockQuote
    var onDismiss: () -> Void
    @ObservedObject private var alertStore = StockAlertStore.shared
    @ObservedObject private var tms = TMSStore.shared
    @State private var upperText = ""
    @State private var lowerText = ""
    @State private var enabled = true
    @State private var showTMS = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text(stock.symbol)
                        .font(.system(size: 13, weight: .bold))
                    Text("LTP: Rs \(String(format: "%.2f", stock.ltp))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if alertStore.hasAlert(for: stock.symbol) {
                    Button {
                        alertStore.removeAlert(for: stock.symbol)
                        onDismiss()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Remove alert")
                }
            }

            Divider()

            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
                Text("Notify if above")
                    .font(.system(size: 11))
                Spacer()
                TextField("Price", text: $upperText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.green.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    )
                    .frame(width: 90)
            }

            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                Text("Notify if below")
                    .font(.system(size: 11))
                Spacer()
                TextField("Price", text: $lowerText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.red.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
                    .frame(width: 90)
            }

            HStack {
                Toggle("Enabled", isOn: $enabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.system(size: 10))

                Spacer()

                Button {
                    let alert = StockAlert(
                        symbol: stock.symbol,
                        upperBound: Double(upperText),
                        lowerBound: Double(lowerText),
                        enabled: enabled
                    )
                    alertStore.setAlert(alert)
                    onDismiss()
                } label: {
                    Text("Save")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.orange))
                }
                .buttonStyle(.plain)
            }

            Divider()

            // TMS Order
            Button { showTMS = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.indigo)
                    Text(tms.isConnected ? "Place Buy/Sell Order" : "Connect TMS to Trade")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.indigo)
                    Spacer()
                    if tms.isConnected {
                        Circle().fill(.green).frame(width: 6, height: 6)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.indigo.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.indigo.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showTMS) {
                TMSLoginView()
            }
        }
        .padding(12)
        .frame(width: 280)
        .onAppear {
            if let existing = alertStore.alert(for: stock.symbol) {
                upperText = existing.upperBound.map { String(format: "%.2f", $0) } ?? ""
                lowerText = existing.lowerBound.map { String(format: "%.2f", $0) } ?? ""
                enabled = existing.enabled
            }
        }
    }
}

// MARK: - Skeleton Shimmer

struct SkeletonBox: View {
    var width: CGFloat
    var height: CGFloat
    var radius: CGFloat = 4
    @State private var shimmer = false

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color.secondary.opacity(0.12))
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.2), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmer ? width : -width)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    shimmer = true
                }
            }
    }
}
