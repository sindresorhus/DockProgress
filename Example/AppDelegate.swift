import Cocoa
import DockProgress

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
	func borrowIconFromApp(_ app: String) {
		let icon = NSWorkspace.shared.icon(forFile: NSWorkspace.shared.fullPath(forApplication: app)!)
		icon.size = CGSize(width: 128, height: 128)
		NSApp.applicationIconImage = icon
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		borrowIconFromApp("Photos")

		let styles: [DockProgress.ProgressStyle] = [
			.bar,
			.squircle(color: .systemGray),
			.circle(radius: 30, color: .white),
			.badge(color: .systemBlue, badgeValue: { Int(DockProgress.progress * 12) })
		]

		var stylesIterator = styles.makeIterator()
		_ = stylesIterator.next()

		Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
			DockProgress.progress += 0.01

			if DockProgress.progress > 1 {
				if let style = stylesIterator.next() {
					DockProgress.resetProgress()
					DockProgress.style = style
				} else {
					// Reset iterator when all is looped.
					stylesIterator = styles.makeIterator()
				}
			}
		}
	}
}
