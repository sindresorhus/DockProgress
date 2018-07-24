import Cocoa
import DockProgress

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {
	func borrowIconFrom(app: String) {
		let icon = NSWorkspace.shared.icon(forFile: NSWorkspace.shared.fullPath(forApplication: app)!)
		icon.size = NSApp.applicationIconImage.size
		NSApp.applicationIconImage = icon
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		borrowIconFrom(app: "Photos")

		var lastStyleWasBar = true
		Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
			DockProgress.progressValue += 0.01

			if DockProgress.progressValue > 1 {
				DockProgress.progressValue = 0
				DockProgress.style = lastStyleWasBar ? .circle(radius: 58, color: .systemPink) : .bar
				lastStyleWasBar = !lastStyleWasBar
			}
		}
	}
}
