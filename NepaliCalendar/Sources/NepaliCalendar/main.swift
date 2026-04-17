import AppKit

// Manual bootstrap — this executable is later packaged into a .app bundle with
// a generated Info.plist. NSApplicationMain isn't used because we're launching
// from a SwiftPM executable target.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
