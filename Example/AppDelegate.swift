import Cocoa
import DockProgress

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {
	func borrowIconFrom(app: String) {
		let icon = NSWorkspace.shared.icon(forFile: NSWorkspace.shared.fullPath(forApplication: app)!)
		icon.size = CGSize(width: 128, height: 128)
		NSApp.applicationIconImage = icon
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		borrowIconFrom(app: "Photos")

		let styles: [DockProgress.ProgressStyle] = [
			.bar,
			.circle(radius: 58, color: .systemPink),
			.badge(color: .systemBlue, badgeValue: { Int(DockProgress.progressValue * 100) })
		]

		var stylesIterator = styles.makeIterator()
		let _ = stylesIterator.next()

		Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
			DockProgress.progressValue += 0.01

			if DockProgress.progressValue > 1 {
				if let style = stylesIterator.next() {
					DockProgress.progressValue = 0
					DockProgress.style = style
				} else {
					// Reset iterator when all is looped
					stylesIterator = styles.makeIterator()
				}
			}
		}
	}
}
