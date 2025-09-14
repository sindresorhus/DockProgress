import SwiftUI
import DockProgress

@MainActor
final class AppState {
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
			.squircle(color: .gray),
			.circle(radius: 30, color: .white),
			.badge(color: .blue) { Int(DockProgress.displayedProgress * 12) },
			.pie(color: .blue),
			.customView { progress in
				CustomView(progress: progress)
			}
		]

		var stylesIterator = styles.makeIterator()
		DockProgress.style = stylesIterator.next()!

		DockProgress.resetProgress()

		Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
			Task { @MainActor in
				DockProgress.progress += 0.2

				if DockProgress.displayedProgress >= 1 {
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

	private func borrowIconFromApp(_ app: String) {
		guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app) else {
			return
		}

		let icon = NSWorkspace.shared.icon(forFile: appURL.path)
		icon.size = CGSize(width: 128, height: 128)

		// Reduce flicker by checking if icon actually changed
		if NSApp.applicationIconImage != icon {
			NSApp.applicationIconImage = icon
		}
	}
}

private struct CustomView: View {
	let progress: Double

	var body: some View {
		ZStack {
			Circle()
				.stroke(
					LinearGradient(
						colors: [.blue, .purple],
						startPoint: .top,
						endPoint: .bottom
					),
					lineWidth: 8
				)
				.opacity(0.3)
				.frame(width: 80, height: 80)
			Circle()
				.trim(from: 0, to: progress)
				.stroke(
					LinearGradient(
						colors: [.blue, .purple],
						startPoint: .top,
						endPoint: .bottom
					),
					style: StrokeStyle(lineWidth: 8, lineCap: .round)
				)
				.rotationEffect(.degrees(-90))
				.frame(width: 80, height: 80)
			Text("\(Int(progress * 100))%")
				.font(.system(size: 20, weight: .bold).monospacedDigit())
				.foregroundColor(.white)
		}
	}
}
