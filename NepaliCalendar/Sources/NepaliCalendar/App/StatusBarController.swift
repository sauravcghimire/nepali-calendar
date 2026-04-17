import AppKit
import SwiftUI

/// Owns the NSStatusItem (the menu-bar icon) and the popover that shows the
/// full calendar. The title text is refreshed on launch and every 10 minutes
/// so it always reflects today's Nepali date.
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var refreshTimer: Timer?
    private var eventMonitor: Any?

    /// Popover frame — must match the `.frame(width:height:)` on CalendarView.
    private static let popoverSize = NSSize(width: 480, height: 620)

    override init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        let hosting = NSHostingController(rootView: CalendarView())
        // Pin the hosting controller to the popover frame so SwiftUI lays out
        // the full view — otherwise NSPopover collapses to the intrinsic size.
        hosting.view.frame = NSRect(origin: .zero, size: Self.popoverSize)
        hosting.preferredContentSize = Self.popoverSize
        popover.contentViewController = hosting
        popover.contentSize = Self.popoverSize
        self.popover = popover

        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
        refreshTitle()
        // Every 10 minutes covers the midnight Kathmandu rollover without thrashing.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.refreshTitle()
        }
    }

    func refreshTitle() {
        guard let button = statusItem.button else { return }
        if let today = CalendarStore.shared.bsDate(forAD: Date()) {
            let info = CalendarStore.shared.byBs[today.bsYear]?[today.bsMonth]?[today.bsDay]
            let isHoliday = info?.isHoliday == true
            let text = "\(NepaliNumerals.devanagari(today.bsDay)) "
                     + "\(NepaliMonth.name(today.bsMonth)), "
                     + NepaliNumerals.devanagari(today.bsYear)
            // Colored pill: blue on normal days, red on holidays, white text.
            button.image = Self.renderPill(text: text, isHoliday: isHoliday)
            button.imagePosition = .imageOnly
            button.title = ""
            button.toolTip = isHoliday ? "Holiday" : nil
        } else {
            button.image = nil
            button.title = "Nepali Calendar"
        }
    }

    /// Render a small rounded-rectangle image (pill) with a colored background
    /// and white text. `isTemplate = false` so AppKit keeps the colors.
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

        image.isTemplate = false  // preserve the blue/red color
        return image
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            stopMonitoringOutsideClicks()
        } else {
            // Re-assert the size in case SwiftUI recomputed intrinsic content size
            // while the popover was hidden. This keeps the "full view" from
            // collapsing to a smaller rect when reopening.
            popover.contentSize = Self.popoverSize
            refreshTitle()
            // `.minY` anchors the arrow to the bottom edge of the status item,
            // so the popover drops down directly below the menu-bar pill.
            popover.show(relativeTo: button.bounds,
                         of: button,
                         preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            startMonitoringOutsideClicks()
        }
    }

    private func startMonitoringOutsideClicks() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self else { return }
            if self.popover.isShown { self.popover.performClose(nil) }
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
