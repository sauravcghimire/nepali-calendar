import SwiftUI

struct StockPanel: View {
    @ObservedObject private var store = StockStore.shared
    @ObservedObject private var settings = Settings.shared
    @State private var searchText = ""
    @State private var hoveredSymbol: String?
    @State private var sortKey: SortKey = .symbol
    @State private var sortAscending = true

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

    private var stockList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 1) {
                ForEach(Array(filteredStocks.enumerated()), id: \.element.id) { idx, stock in
                    let isFav = settings.isStockFavorite(stock.symbol)
                    if idx > 0 && !isFav && settings.isStockFavorite(filteredStocks[idx - 1].symbol) {
                        Divider().padding(.vertical, 1)
                    }
                    stockRow(stock, isEven: idx.isMultiple(of: 2), isFavorite: isFav)
                }
            }
        }
    }

    private func stockRow(_ stock: StockQuote, isEven: Bool, isFavorite: Bool) -> some View {
        let isHovered = hoveredSymbol == stock.symbol
        let dir = stock.direction

        return HStack(spacing: 0) {
            Button { settings.toggleFavoriteStock(stock.symbol) } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 9))
                    .foregroundStyle(isFavorite ? .yellow : .secondary.opacity(0.25))
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
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isFavorite
                    ? Color.yellow.opacity(isHovered ? 0.10 : 0.04)
                    : (isHovered
                        ? Color.accentColor.opacity(0.10)
                        : (isEven ? Color.secondary.opacity(0.03) : Color.clear)))
        )
        .onHover { hoveredSymbol = $0 ? stock.symbol : nil }
        .help("O: \(formatPrice(stock.open))  H: \(formatPrice(stock.high))  L: \(formatPrice(stock.low))  PC: \(formatPrice(stock.prevClose))")
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
        VStack(spacing: 8) {
            Spacer()
            ProgressView().controlSize(.small)
            Text("Loading market data…").font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
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
