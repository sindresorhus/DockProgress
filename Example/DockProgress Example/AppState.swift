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
			.badge(color: .systemBlue) { Int(DockProgress.animatedProgress * 12) },
			.pie(color: .systemBlue)
		]

		var stylesIterator = styles.makeIterator()
		DockProgress.style = stylesIterator.next()!
		
		DockProgress.resetProgress()

		Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
			DockProgress.progress += 0.2

			if DockProgress.animatedProgress >= 1 {
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
