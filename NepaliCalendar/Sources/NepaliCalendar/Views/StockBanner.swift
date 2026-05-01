import SwiftUI

struct StockBannerView: View {
    @ObservedObject private var alertStore = StockAlertStore.shared
    var onTap: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            ForEach(alertStore.pendingNotifications) { notif in
                bannerCard(notif)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: alertStore.pendingNotifications.count)
    }

    private func bannerCard(_ notif: StockNotification) -> some View {
        let accent: Color = notif.isAbove ? .green : .red
        let icon = notif.isAbove ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill"

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(notif.title)
                    .font(.system(size: 13, weight: .bold))
                Text(notif.message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation { alertStore.dismissNotification(notif.id) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accent.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: accent.opacity(0.2), radius: 8, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation { alertStore.dismissNotification(notif.id) }
            onTap()
        }
    }
}
