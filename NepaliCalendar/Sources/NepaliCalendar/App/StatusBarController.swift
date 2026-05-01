import AppKit
import Combine
import SwiftUI

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let panel: NSPanel
    private let hostingView: NSHostingView<CalendarView>
    private var refreshTimer: Timer?

    private var bannerPanels: [NSPanel] = []
    private var bannerSub: AnyCancellable?

    override init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let hostingView = NSHostingView(rootView: CalendarView())
        self.hostingView = hostingView

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .mainMenu + 1
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isMovable = true
        panel.isOpaque = false
        panel.backgroundColor = .windowBackgroundColor
        panel.hasShadow = true
        panel.contentView = hostingView
        self.panel = panel

        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePanel(_:))
        }
        refreshTitle()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.refreshTitle()
        }

        bannerSub = StockAlertStore.shared.$pendingNotifications
            .receive(on: RunLoop.main)
            .sink { [weak self] notifs in
                if notifs.isEmpty {
                    self?.hideBanners()
                } else {
                    self?.showBannersOnAllScreens()
                }
            }
    }

    // MARK: - Banner Management

    private func makeBannerPanel() -> NSPanel {
        let bp = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        bp.isFloatingPanel = true
        bp.level = .screenSaver
        bp.titleVisibility = .hidden
        bp.titlebarAppearsTransparent = true
        bp.isMovable = false
        bp.isOpaque = false
        bp.backgroundColor = .clear
        bp.hasShadow = false

        let bannerView = NSHostingView(rootView:
            StockBannerView { [weak self] in
                self?.showMainPanel()
            }
            .frame(width: 340)
        )
        bp.contentView = bannerView
        return bp
    }

    private func showBannersOnAllScreens() {
        let screens = NSScreen.screens
        // Add panels if we need more
        while bannerPanels.count < screens.count {
            bannerPanels.append(makeBannerPanel())
        }

        for (i, screen) in screens.enumerated() {
            let bp = bannerPanels[i]
            let visible = screen.visibleFrame
            let w: CGFloat = 360
            let h: CGFloat = 260
            let x = visible.maxX - w - 12
            let y = visible.maxY - h - 8
            bp.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
            bp.orderFrontRegardless()
        }

        // Hide extra panels if screens were removed
        for i in screens.count..<bannerPanels.count {
            bannerPanels[i].orderOut(nil)
        }
    }

    private func hideBanners() {
        for bp in bannerPanels {
            bp.orderOut(nil)
        }
    }

    // MARK: - Main Panel

    private func showMainPanel() {
        refreshTitle()
        positionPanel()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refreshTitle() {
        guard let button = statusItem.button else { return }
        if let today = CalendarStore.shared.bsDate(forAD: Date()) {
            let isHoliday = CalendarStore.shared.isEffectiveHoliday(
                bsYear: today.bsYear,
                bsMonth: today.bsMonth,
                bsDay: today.bsDay
            )
            let text = "\(NepaliNumerals.devanagari(today.bsDay)) "
                     + "\(NepaliMonth.name(today.bsMonth)), "
                     + NepaliNumerals.devanagari(today.bsYear)
            button.image = Self.renderPill(text: text, isHoliday: isHoliday)
            button.imagePosition = .imageOnly
            button.title = ""
            button.toolTip = isHoliday ? "Holiday" : nil
        } else {
            button.image = nil
            button.title = "Nepali Calendar"
        }
    }

    private static func renderPill(text: String, isHoliday: Bool) -> NSImage {
        let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let ns = text as NSString
        let textSize = ns.size(withAttributes: attrs)

        let hPad: CGFloat = 8
        let vPad: CGFloat = 2
        let w = ceil(textSize.width + hPad * 2)
        let h = max(ceil(textSize.height + vPad * 2), 18)

        let image = NSImage(size: NSSize(width: w, height: h))
        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = NSRect(x: 0, y: 0, width: w, height: h)
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5),
                                xRadius: 5, yRadius: 5)
        let bg: NSColor = isHoliday ? .systemRed : .systemBlue
        bg.setFill()
        path.fill()

        let tx = (w - textSize.width) / 2
        let ty = (h - textSize.height) / 2
        ns.draw(at: NSPoint(x: tx, y: ty), withAttributes: attrs)

        image.isTemplate = false
        return image
    }

    @objc private func togglePanel(_ sender: Any?) {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            showMainPanel()
        }
    }

    private func positionPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window,
              let screen = buttonWindow.screen ?? NSScreen.main else { return }

        let buttonRect = buttonWindow.convertToScreen(
            button.convert(button.bounds, to: nil))
        let fittingSize = hostingView.fittingSize
        let visible = screen.visibleFrame
        let padding: CGFloat = 4

        let maxW = visible.width - padding * 2
        let maxH = visible.height - padding * 2
        let w = min(fittingSize.width, maxW)
        let h = min(fittingSize.height, maxH)

        let x = max(visible.minX + padding,
                    min(buttonRect.midX - w / 2,
                        visible.maxX - w - padding))
        let y = max(visible.minY + padding,
                    buttonRect.minY - h)

        panel.setFrame(NSRect(x: x, y: y, width: w, height: h),
                       display: true)
    }
}
