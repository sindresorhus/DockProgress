import Cocoa
import SwiftUI

/**
Show progress in your app's Dock icon.

Use either ``progress`` or ``progressInstance``.
*/
@MainActor
public enum DockProgress {
	private static var progressObserver: NSKeyValueObservation?
	private static var finishedObserver: NSKeyValueObservation?
	private static var elapsedTimeSinceLastRefresh = 0.0
	private static var isResetting = false

	// TODO: Use `CADisplayLink` on macOS 14.
	private static var displayLinkObserver: DisplayLinkObserver = {
		DisplayLinkObserver { observer, refreshPeriod in
			let speed = 1.0

			elapsedTimeSinceLastRefresh += speed * refreshPeriod

			if (displayedProgress - progress).magnitude <= 0.01 {
				displayedProgress = progress
				elapsedTimeSinceLastRefresh = 0
				observer.stop()
			} else {
				displayedProgress = Easing.linearInterpolation(
					start: displayedProgress,
					end: progress,
					progress: Easing.easeInOut(progress: elapsedTimeSinceLastRefresh)
				)
			}

			updateDockIcon()
		}
	}()

	private static let dockContentView: ContentView = {
		let view = ContentView()
		NSApp?.dockTile.contentView = view
		return view
	}()

	/**
	Assign a [`Progress`](https://developer.apple.com/documentation/foundation/progress) instance to track the progress status.

	When set to `nil`, the progress will be reset.

	The given `Progress` instance is weakly stored. It's up to you to retain it.

	```swift
	import Foundation
	import DockProgress

	let progress = Progress(totalUnitCount: 1)
	progress?.becomeCurrent(withPendingUnitCount: 1)

	DockProgress.progressInstance = progress
	```
	*/
	public static weak var progressInstance: Progress? {
		didSet {
			guard let progressInstance else {
				progressObserver = nil
				finishedObserver = nil
				resetProgress()
				return
			}

			// TODO: Use AsyncSequence when targeting macOS 15.
			progressObserver = progressInstance.observe(\.fractionCompleted) { sender, _ in
				Task { @MainActor in
					guard
						!sender.isCancelled,
						!sender.isFinished
					else {
						return
					}

					progress = sender.fractionCompleted
				}
			}

			finishedObserver = progressInstance.observe(\.isFinished) { sender, _ in
				Task { @MainActor in
					guard
						!sender.isCancelled,
						sender.isFinished
					else {
						return
					}

					progress = 1
				}
			}
		}
	}

	/**
	Indicates the current progress from 0.0 to 1.0. Setting this value will start the animation towards the set value.

	```swift
	import DockProgress

	foo.onUpdate = { progress in
		DockProgress.progress = progress
	}
	```
	*/
	public static var progress: Double = 0 {
		didSet {
			if progress > 0 {
				NSApp?.dockTile.contentView = dockContentView
				// Snap only when coming from completed state (>= 1), not from 0
				if displayedProgress >= 1 {
					displayedProgress = progress
					elapsedTimeSinceLastRefresh = 0
					updateDockIcon()
				} else {
					displayLinkObserver.start()
				}
			} else {
				displayLinkObserver.stop()
				displayedProgress = max(0, min(1, progress))
				if !isResetting {
					NSApp?.dockTile.contentView = nil
				}
				updateDockIcon()
			}
		}
	}

	/**
	The currently displayed progress. Animates towards ``progress``.
	*/
	public private(set) static var displayedProgress = 0.0 {
		didSet {
			if displayedProgress == 0 || displayedProgress >= 1 {
				dockContentView.resetHostingView()
			}
		}
	}

	/**
	Reset the progress without animating.
	*/
	public static func resetProgress() {
		isResetting = true
		displayLinkObserver.stop()
		displayedProgress = 0
		progress = 0
		elapsedTimeSinceLastRefresh = 0
		isResetting = false

		// Only remove contentView if not immediately restarting progress
		DispatchQueue.main.async {
			if progress == 0 {
				NSApp?.dockTile.contentView = nil
				updateDockIcon()
			}
		}
	}

	/**
	The style to be used for displaying progress.

	The default style is `.bar`.

	Check out the example app in the Xcode project for a demo of the styles.
	*/
	public static var style = Style.bar

	private static func updateDockIcon() {
		dockContentView.needsDisplay = true
		NSApp?.dockTile.display()
	}

	private static func withCGContext(_ action: (CGContext) -> Void) {
		guard let cgContext = NSGraphicsContext.current?.cgContext else {
			return
		}

		action(cgContext)
	}

	/**
	```
	999 => 999
	1000 => 1K
	1100 => 1K
	2000 => 2K
	10000 => 9K+
	```
	*/
	static func kiloShortStringFromInt(number: Int) -> String {
		let absNumber = abs(number)

		switch absNumber {
		case 0..<1000:
			return "\(number)"
		case 1000..<10_000:
			return "\(number.signum() * (absNumber / 1000))k"
		default:
			return "\(number.signum() * 9)k+"
		}
	}

	static func scaledBadgeFontSize(text: String) -> Double {
		switch text.count {
		case 1:
			30
		case 2:
			23
		case 3:
			19
		case 4:
			15
		default:
			0
		}
	}
}

extension DockProgress {
	/**
	The available progress styles.

	- `.bar` ![](https://github.com/sindresorhus/DockProgress/blob/main/screenshot-bar.gif?raw=true)
	- `.squircle` ![](https://github.com/sindresorhus/DockProgress/blob/main/screenshot-squircle.gif?raw=true)
	- `.circle` ![](https://github.com/sindresorhus/DockProgress/blob/main/screenshot-circle.gif?raw=true)
	- `.badge` ![](https://github.com/sindresorhus/DockProgress/blob/main/screenshot-badge.gif?raw=true)
	- `.pie` ![](https://github.com/sindresorhus/DockProgress/blob/main/screenshot-pie.gif?raw=true)
	*/
	public enum Style: Sendable {
		/**
		Progress bar style.

		![](https://github.com/sindresorhus/DockProgress/blob/main/screenshot-bar.gif?raw=true)
		*/
		case bar

		/**
		Progress line animating around the edges of the app icon.

		- Parameters:
			- inset: Inset value to adjust the squircle shape. By default, it should fit a normal macOS icon.
			- color: The color of the progress.

		![](https://github.com/sindresorhus/DockProgress/blob/main/screenshot-squircle.gif?raw=true)
		*/
		case squircle(inset: Double? = nil, color: Color = .accentColor)

		/**
		Circle style.

		- Parameters:
			- radius: The radius of the circle.
			- color: The color of the progress.

		![](https://github.com/sindresorhus/DockProgress/blob/main/screenshot-circle.gif?raw=true)
		*/
		case circle(radius: Double, color: Color = .accentColor)

		/**
		Badge style.

		- Parameters:
			- color: The color of the badge.
			- badgeValue: A closure that returns the badge value as an integer.

		- Note: It is not meant to be used as a numeric percentage. It's for things like count of downloads, number of files being converted, etc.

		Large badge value numbers will be written in kilo short notation, for example, `1012` → `1k`.

		![](https://github.com/sindresorhus/DockProgress/blob/main/screenshot-badge.gif?raw=true)
		*/
		case badge(color: Color = .accentColor, badgeValue: @MainActor () -> Int)

		/**
		Pie style.

		- Parameters:
			- color: The color of the pie.

		![](https://github.com/sindresorhus/DockProgress/blob/main/screenshot-pie.gif?raw=true)
		*/
		case pie(color: Color = .accentColor)

		/**
		Custom style using a SwiftUI view.

		- Parameters:
			- view: A closure that returns a SwiftUI view to display as the progress indicator.

		- Note: The view will be overlaid on top of the app icon. Make sure to design your view with transparency in mind.
		*/
		case customView(@MainActor (_ progress: Double) -> any View)

		/**
		Custom style using SwiftUI Canvas for drawing.

		- Parameters:
			- canvasRenderer: A closure that draws directly on a SwiftUI Canvas.

		- Note: This provides a SwiftUI-native way to create custom progress indicators with immediate mode drawing.
		*/
		case customCanvas(@MainActor (_ context: GraphicsContext, _ size: CGSize, _ progress: Double) -> Void)

		/**
		Custom style using legacy Core Graphics drawing.

		- Parameters:
			- drawHandler: A closure that is responsible for drawing the custom progress.
		*/
		case custom(drawHandler: @MainActor (_ rect: CGRect) -> Void)
	}
}

extension DockProgress {
	private final class ContentView: NSView {
		private var hostingView: NSView?

		func resetHostingView() {
			hostingView?.removeFromSuperview()
			hostingView = nil
		}

		var hasHostingView: Bool {
			hostingView != nil
		}

		override func draw(_ dirtyRect: CGRect) {
			NSGraphicsContext.current?.imageInterpolation = .high

			NSApp?.applicationIconImage?.draw(in: bounds)

			// TODO: If the `progress` is 1, draw the full circle, then schedule another draw in n milliseconds to hide it
			guard
				displayedProgress > 0,
				displayedProgress < 1
			else {
				resetHostingView()
				return
			}

			switch style {
			case .bar:
				updateHostingView(with: CanvasBarStyle(progress: displayedProgress))
			case .squircle(let inset, let color):
				updateHostingView(with: CanvasSquircleStyle(progress: displayedProgress, inset: inset, color: color))
			case .circle(let radius, let color):
				updateHostingView(with: CanvasCircleStyle(progress: displayedProgress, radius: radius, color: color))
			case .badge(let color, let badgeValue):
				updateHostingView(with: CanvasBadgeStyle(progress: displayedProgress, color: color, badgeValue: badgeValue()))
			case .pie(let color):
				updateHostingView(with: CanvasPieStyle(progress: displayedProgress, color: color))
			case .custom(let drawingHandler):
				resetHostingView()
				drawingHandler(bounds)
			case .customView(let viewProvider):
				updateHostingView(with: viewProvider(displayedProgress))
			case .customCanvas(let canvasRenderer):
				updateHostingView(with: Canvas { context, size in
					canvasRenderer(context, size, displayedProgress)
				})
			}
		}

		private func updateHostingView(with view: any View) {
			if hostingView == nil {
				let hosting = NSHostingView(rootView: AnyView(view))
				hosting.frame = bounds
				hosting.autoresizingMask = [.width, .height]
				addSubview(hosting)
				hostingView = hosting
			} else if let hosting = hostingView as? NSHostingView<AnyView> {
				hosting.rootView = AnyView(view)
			}

			// Force immediate layout and display to ensure Canvas renders with current displayedProgress value.
			// Without this, Canvas would render on the next frame using the previous progress value.
			hostingView?.layoutSubtreeIfNeeded()
			hostingView?.displayIfNeeded()
		}
	}
}

extension DockProgress {
	static func testingRenderCurrentStyle(progress: Double) {
		dockContentView.frame = CGRect(
			x: 0,
			y: 0,
			width: canvasFrameWidth,
			height: canvasFrameHeight
		)
		displayedProgress = progress
		dockContentView.draw(dockContentView.bounds)
	}

	static var testingHasActiveHostingView: Bool {
		dockContentView.hasHostingView
	}
}

private extension DockProgress {
	/**
	Standard frame dimensions for all Canvas styles.
	*/
	static let canvasFrameWidth: CGFloat = 128
	static let canvasFrameHeight: CGFloat = 128

	/**
	Progress multiplier to ensure start and end points meet (accounts for round line caps).
	*/
	static let progressMultiplier: Double = 1.02
}

extension Path {
	/**
	Creates a superellipse (squircle) path within the given rectangle.
	*/
	static func squircle(in rect: CGRect) -> Path {
		let minSide = min(rect.width, rect.height)
		let radius = min(rect.width / 2, minSide / 2)

		let corners = (
			topLeft: CGPoint(x: rect.minX, y: rect.minY),
			topRight: CGPoint(x: rect.maxX, y: rect.minY),
			bottomLeft: CGPoint(x: rect.minX, y: rect.maxY),
			bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
		)

		let points = (
			p1: CGPoint(x: rect.minX + radius, y: rect.minY),
			p2: CGPoint(x: rect.maxX - radius, y: rect.minY),
			p3: CGPoint(x: rect.maxX, y: rect.minY + radius),
			p4: CGPoint(x: rect.maxX, y: rect.maxY - radius),
			p5: CGPoint(x: rect.maxX - radius, y: rect.maxY),
			p6: CGPoint(x: rect.minX + radius, y: rect.maxY),
			p7: CGPoint(x: rect.minX, y: rect.maxY - radius),
			p8: CGPoint(x: rect.minX, y: rect.minY + radius)
		)

		return Path { path in
			path.move(to: points.p1)
			path.addLine(to: points.p2)
			path.addCurve(to: points.p3, control1: corners.topRight, control2: corners.topRight)
			path.addLine(to: points.p4)
			path.addCurve(to: points.p5, control1: corners.bottomRight, control2: corners.bottomRight)
			path.addLine(to: points.p6)
			path.addCurve(to: points.p7, control1: corners.bottomLeft, control2: corners.bottomLeft)
			path.addLine(to: points.p8)
			path.addCurve(to: points.p1, control1: corners.topLeft, control2: corners.topLeft)
		}
	}

	// Creates a progress circle path starting from the top and going clockwise.
	static func progressCircle(center: CGPoint, radius: Double) -> Path {
		Path { path in
			path.addArc(
				center: center,
				radius: radius,
				startAngle: .degrees(-90),
				endAngle: .degrees(270),
				clockwise: false
			)
		}
	}
}

extension CGRect {
	/**
	Creates a rectangle for a circle with the given center and radius.
	*/
	static func circleRect(center: CGPoint, radius: Double) -> CGRect {
		CGRect(
			x: center.x - radius,
			y: center.y - radius,
			width: radius * 2,
			height: radius * 2
		)
	}
}

struct CanvasBarStyle: View {
	private static let barStrokeWidth = 10.0

	let progress: Double

	var body: some View {
		Canvas { context, size in
			let barInset = 8.0

			let barRect = CGRect(
				x: barInset,
				y: size.height - 30,
				width: size.width - (barInset * 2),
				height: 10
			)

			// Background bar
			context.fill(
				RoundedRectangle(cornerRadius: 5).path(in: barRect),
				with: .color(.white.opacity(0.8))
			)

			// Inner background
			let innerRect = barRect.insetBy(dx: 0.5, dy: 0.5)
			context.fill(
				RoundedRectangle(cornerRadius: 4.5).path(in: innerRect),
				with: .color(.black.opacity(0.8))
			)

			// Progress fill
			let progressWidth = max(0, (barRect.width - 2) * progress)
			if progressWidth > 0 {
				let progressRect = CGRect(
					x: barRect.minX + 1,
					y: barRect.minY + 1,
					width: progressWidth,
					height: barRect.height - 2
				)
				context.fill(
					RoundedRectangle(cornerRadius: 4).path(in: progressRect),
					with: .color(.white)
				)
			}
		}
	}
}

struct CanvasSquircleStyle: View {
	private static let squircleStrokeWidth = 5.0
	private static let defaultSquircleInset = 14.4

	let progress: Double
	let inset: Double?
	let color: Color

	var body: some View {
		Canvas { context, size in
			let totalInset = Self.defaultSquircleInset + (inset ?? 0)
			let rect = CGRect(origin: .zero, size: size).insetBy(dx: totalInset, dy: totalInset)
			let path = Path.squircle(in: rect)

			context.stroke(
				path.trimmedPath(from: 0, to: progress * DockProgress.progressMultiplier),
				with: .color(color),
				style: StrokeStyle(lineWidth: Self.squircleStrokeWidth, lineCap: .round)
			)
		}
	}
}

struct CanvasCircleStyle: View {
	private static let circleStrokeWidth = 4.0

	let progress: Double
	let radius: Double
	let color: Color

	var body: some View {
		Canvas { context, size in
			let center = CGPoint(x: size.width / 2, y: size.height / 2)
			let path = Path.progressCircle(center: center, radius: radius)

			context.stroke(
				path.trimmedPath(from: 0, to: progress * DockProgress.progressMultiplier),
				with: .color(color),
				style: StrokeStyle(lineWidth: Self.circleStrokeWidth, lineCap: .round)
			)
		}
	}
}

struct CanvasBadgeStyle: View {
	private static let radiusDivisor = 4.8
	private static let progressInset = 3.0
	private static let strokeWidth = 6.0
	static let backgroundColor = Color(red: 0.94, green: 0.96, blue: 1.0)
	static let textColor = Color(red: 0.23, green: 0.23, blue: 0.24)

	let progress: Double
	let color: Color
	let badgeValue: Int

	var body: some View {
		Canvas { context, size in
			let radius = size.width / Self.radiusDivisor
			let center = CGPoint(x: size.width - radius - 4, y: size.height - radius - 4)

			// Background
			let bgRect = CGRect.circleRect(center: center, radius: radius)
			context.fill(
				Circle().path(in: bgRect),
				with: .color(Self.backgroundColor)
			)

			// Progress ring
			let progressRadius = radius - Self.progressInset
			let progressPath = Path.progressCircle(center: center, radius: progressRadius)

			context.stroke(
				progressPath.trimmedPath(from: 0, to: progress * DockProgress.progressMultiplier),
				with: .color(color),
				style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .butt)
			)

			// Badge text
			let text = DockProgress.kiloShortStringFromInt(number: badgeValue)
			context.draw(
				Text(text)
					.font(.system(size: DockProgress.scaledBadgeFontSize(text: text), weight: .bold))
					.foregroundColor(Self.textColor),
				at: center
			)
		}
	}
}

struct CanvasPieStyle: View {
	private static let radiusDivisor = 4.8

	let progress: Double
	let color: Color

	var body: some View {
		Canvas { context, size in
			let radius = size.width / Self.radiusDivisor
			let center = CGPoint(x: size.width - radius - 4, y: size.height - radius - 4)

			// Background
			let bgRect = CGRect.circleRect(center: center, radius: radius)
			context.fill(
				Circle().path(in: bgRect),
				with: .color(CanvasBadgeStyle.backgroundColor)
			)

			// Pie wedge
			if progress > 0 {
				let path = Path { path in
					path.move(to: center)
					path.addArc(
						center: center,
						radius: radius,
						startAngle: .degrees(-90),
						endAngle: .degrees(-90 + 360 * progress),
						clockwise: false
					)
					path.closeSubpath()
				}
				context.fill(path, with: .color(color))
			}
		}
	}
}
