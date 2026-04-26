import AppKit
import SwiftUI

/// Owns the NSStatusItem (the menu-bar icon) and a panel that shows the
/// full calendar. The title text is refreshed on launch and every 10 minutes
/// so it always reflects today's Nepali date.
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let panel: NSPanel
    private let hostingView: NSHostingView<CalendarView>
    private var refreshTimer: Timer?
    private var eventMonitor: Any?

    override init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let hostingView = NSHostingView(rootView: CalendarView())
        self.hostingView = hostingView

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .mainMenu + 1
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovable = false
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
            stopMonitoringOutsideClicks()
        } else {
            refreshTitle()
            positionPanel()
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            startMonitoringOutsideClicks()
        }
    }

    private func positionPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window,
              let screen = buttonWindow.screen ?? NSScreen.main else { return }

        let buttonRect = buttonWindow.convertToScreen(
            button.convert(button.bounds, to: nil))
        let size = hostingView.fittingSize
        let screenFrame = screen.frame

        let x = max(screenFrame.minX + 4,
                    min(buttonRect.midX - size.width / 2,
                        screenFrame.maxX - size.width - 4))
        // Vertically: directly below the menu bar
        let y = buttonRect.minY - size.height

        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height),
                       display: true)
    }

    private func startMonitoringOutsideClicks() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self else { return }
            if self.panel.isVisible { self.panel.orderOut(nil) }
            self.stopMonitoringOutsideClicks()
        }
    }

    private func stopMonitoringOutsideClicks() {
        if let m = eventMonitor {
            NSEvent.removeMonitor(m)
            eventMonitor = nil
        }
    }
}
