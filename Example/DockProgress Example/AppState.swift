import SwiftUI
import DockProgress

@MainActor
final class AppState: ObservableObject {
	init() {
		DispatchQueue.main.async { [self] in
			didLaunch()
		}
	}

	private func didLaunch() {
		runExample()
	}

	private func runExample() {
		borrowIconFromApp("com.apple.Photos")

		let styles: [DockProgress.Style] = [
			.bar,
			.squircle(color: .systemGray),
			.circle(radius: 30, color: .white),
			.badge(color: .systemBlue) { Int(DockProgress.progress * 12) }
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

	private func borrowIconFromApp(_ app: String) {
		let icon = NSWorkspace.shared.icon(forFile: NSWorkspace.shared.urlForApplication(withBundleIdentifier: app)!.path)
		icon.size = CGSize(width: 128, height: 128)
		NSApp.applicationIconImage = icon
	}
}
