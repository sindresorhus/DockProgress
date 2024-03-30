import Cocoa

/**
Show progress in your app's Dock icon.

Use either ``progress`` or ``progressInstance``.
*/
@MainActor
public enum DockProgress {
	private static var progressObserver: NSKeyValueObservation?
	private static var finishedObserver: NSKeyValueObservation?
	private static var elapsedTimeSinceLastRefresh = 0.0

	// TODO: Use `CADisplayLink` on macOS 14.
	private static var displayLinkObserver = DisplayLinkObserver { displayLinkObserver, refreshPeriod in
		DispatchQueue.main.async {
			let speed = 1.0

			elapsedTimeSinceLastRefresh += speed * refreshPeriod

			if (displayedProgress - progress).magnitude <= 0.01 {
				displayedProgress = progress
				elapsedTimeSinceLastRefresh = 0
				displayLinkObserver.stop()
			} else {
				displayedProgress = Easing.linearInterpolation(
					start: displayedProgress,
					end: progress,
					progress: Easing.easeInOut(progress: elapsedTimeSinceLastRefresh)
				)
			}

			updateDockIcon()
		}
	}

	private static let dockContentView = with(ContentView()) {
		NSApp.dockTile.contentView = $0
	}

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
				NSApp.dockTile.contentView = dockContentView
				displayLinkObserver.start()
			} else {
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
				NSApp.dockTile.contentView = nil
			}
 		}
	}

	/**
	Reset the progress without animating.
	*/
	public static func resetProgress() {
		displayLinkObserver.stop()
		progress = 0
		displayedProgress = 0
		elapsedTimeSinceLastRefresh = 0
		updateDockIcon()
	}

	/**
	The style to be used for displaying progress.

	The default style is `.bar`.

	Check out the example app in the Xcode project for a demo of the styles.
	*/
	public static var style = Style.bar

	private static func updateDockIcon() {
		dockContentView.needsDisplay = true
		NSApp.dockTile.display()
	}

	private final class ContentView: NSView {
		override func draw(_ dirtyRect: CGRect) {
			NSGraphicsContext.current?.imageInterpolation = .high

			NSApp.applicationIconImage?.draw(in: bounds)

			// TODO: If the `progress` is 1, draw the full circle, then schedule another draw in n milliseconds to hide it
			guard
				displayedProgress > 0,
				displayedProgress < 1
			else {
				return
			}

			switch style {
			case .bar:
				drawProgressBar(bounds)
			case .squircle(let inset, let color):
				drawProgressSquircle(bounds, inset: inset, color: color)
			case .circle(let radius, let color):
				drawProgressCircle(bounds, radius: radius, color: color)
			case .badge(let color, let badgeValue):
				drawProgressBadge(bounds, color: color, badgeLabel: badgeValue())
			case .pie(let color):
				drawProgressBadge(bounds, color: color, badgeLabel: 0, isPie: true)
			case .custom(let drawingHandler):
				drawingHandler(bounds)
			}
		}
	}

	private static func drawProgressBar(_ dstRect: CGRect) {
		func roundedRect(_ rect: CGRect) {
			NSBezierPath(roundedRect: rect, cornerRadius: rect.height / 2).fill()
		}

		let bar = CGRect(x: 0, y: 20, width: dstRect.width, height: 10)
		NSColor.white.withAlpha(0.8).set()
		roundedRect(bar)

		let barInnerBg = bar.insetBy(dx: 0.5, dy: 0.5)
		NSColor.black.withAlpha(0.8).set()
		roundedRect(barInnerBg)

		var barProgress = bar.insetBy(dx: 1, dy: 1)
		barProgress.size.width = barProgress.width * displayedProgress
		NSColor.white.set()
		roundedRect(barProgress)
	}

	private static func drawProgressSquircle(_ dstRect: CGRect, inset: Double? = nil, color: NSColor) {
		guard let cgContext = NSGraphicsContext.current?.cgContext else {
			return
		}

		let defaultInset = 14.4

		var rect = dstRect.insetBy(dx: defaultInset, dy: defaultInset)

		if let inset {
			rect = rect.insetBy(dx: inset, dy: inset)
		}

		let progressSquircle = ProgressSquircleShapeLayer(rect: rect)
		progressSquircle.strokeColor = color.cgColor
		progressSquircle.lineWidth = 5
		progressSquircle.progress = displayedProgress
		progressSquircle.render(in: cgContext)
	}

	private static func drawProgressCircle(_ dstRect: CGRect, radius: Double, color: NSColor) {
		guard let cgContext = NSGraphicsContext.current?.cgContext else {
			return
		}

		let progressCircle = ProgressCircleShapeLayer(radius: radius, center: dstRect.center)
		progressCircle.strokeColor = color.cgColor
		progressCircle.lineWidth = 4
		progressCircle.progress = displayedProgress
		progressCircle.render(in: cgContext)
	}

	private static func drawProgressBadge(_ dstRect: CGRect, color: NSColor, badgeLabel: Int, isPie: Bool = false) {
		guard let cgContext = NSGraphicsContext.current?.cgContext else {
			return
		}

		let radius = dstRect.width / 4.8
		let newCenter = CGPoint(x: dstRect.maxX - radius - 4, y: dstRect.minY + radius + 4)

		// Background
		let badge = ProgressCircleShapeLayer(radius: radius, center: newCenter)
		badge.fillColor = CGColor(red: 0.94, green: 0.96, blue: 1, alpha: 1)
		badge.shadowColor = .black
		badge.shadowOpacity = 0.3
		badge.masksToBounds = false
		badge.shadowOffset = CGSize(width: -1, height: 1)
		badge.shadowPath = badge.path

		// Progress circle
		let lineWidth = isPie ? radius : 6.0
		let innerRadius = radius - lineWidth / 2
		let progressCircle = ProgressCircleShapeLayer(radius: innerRadius, center: newCenter)
		progressCircle.strokeColor = color.cgColor
		progressCircle.lineWidth = lineWidth
		progressCircle.lineCap = .butt
		progressCircle.progress = displayedProgress

		// Label
		if !isPie {
			let dimension = badge.bounds.height - 5
			let rect = CGRect(origin: progressCircle.bounds.origin, size: CGSize(width: dimension, height: dimension))
			let textLayer = VerticallyCenteredTextLayer(frame: rect, center: newCenter)
			let badgeText = kiloShortStringFromInt(number: badgeLabel)
			textLayer.foregroundColor = CGColor(red: 0.23, green: 0.23, blue: 0.24, alpha: 1)
			textLayer.string = badgeText
			textLayer.fontSize = scaledBadgeFontSize(text: badgeText)
			textLayer.font = NSFont.helveticaNeueBold
			textLayer.alignmentMode = .center
			textLayer.truncationMode = .end

			badge.addSublayer(textLayer)
		}

		badge.addSublayer(progressCircle)
		badge.render(in: cgContext)
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
	private static func kiloShortStringFromInt(number: Int) -> String {
		let sign = number.signum()
		let absNumber = abs(number)

		if absNumber < 1000 {
			return "\(number)"
		}

		if absNumber < 10_000 {
			return "\(sign * Int(absNumber / 1000))k"
		}

		return "\(sign * 9)k+"
	}

	private static func scaledBadgeFontSize(text: String) -> Double {
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
		case squircle(inset: Double? = nil, color: NSColor = .controlAccentColor)

		/**
		Circle style.

		- Parameters:
			- radius: The radius of the circle.
			- color: The color of the progress.

		![](https://github.com/sindresorhus/DockProgress/blob/main/screenshot-circle.gif?raw=true)
		*/
		case circle(radius: Double, color: NSColor = .controlAccentColor)

		/**
		Badge style.

		- Parameters:
			- color: The color of the badge.
			- badgeValue: A closure that returns the badge value as an integer.

		- Note: It is not meant to be used as a numeric percentage. It's for things like count of downloads, number of files being converted, etc.

		Large badge value numbers will be written in kilo short notation, for example, `1012` → `1k`.

		![](https://github.com/sindresorhus/DockProgress/blob/main/screenshot-badge.gif?raw=true)
		*/
		case badge(color: NSColor = .controlAccentColor, badgeValue: @MainActor @Sendable () -> Int)

		/**
		Pie style.

		- Parameters:
			- color: The color of the pie.

		![](https://github.com/sindresorhus/DockProgress/blob/main/screenshot-pie.gif?raw=true)
		*/
		case pie(color: NSColor = .controlAccentColor)


		/**
		Custom style.

		- Parameters:
			- drawHandler: A closure that is responsible for drawing the custom progress.
		*/
		case custom(drawHandler: @MainActor @Sendable (_ rect: CGRect) -> Void)
	}
}
