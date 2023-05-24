import Cocoa

@MainActor
public enum DockProgress {
	private static var progressObserver: NSKeyValueObservation?
	private static var finishedObserver: NSKeyValueObservation?

	private static var t = 0.0
	private static var displayLinkObserver = DisplayLinkObserver { (displayLinkObserver, refreshPeriod) in
		DispatchQueue.main.async {
			let speed = 1.0
			t += speed * refreshPeriod
			if (animatedProgress - progress).magnitude <= 0.01 {
				animatedProgress = progress
				t = 0
				displayLinkObserver.stop()
			} else {
				animatedProgress = Easing.lerp(animatedProgress, progress, Easing.easeInOut(t));
			}
			updateDockIcon()
		}
	}

	private static let dockContentView = with(ContentView()) {
		NSApp.dockTile.contentView = $0
	}

	public static weak var progressInstance: Progress? {
		didSet {
			guard let progressInstance else {
				progressObserver = nil
				finishedObserver = nil
				resetProgress()
				return
			}

			// TODO: Use AsyncSequence when targeting macOS 12.
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

	public static var progress: Double = 0 {
		didSet {
			if progress > 0 {
				displayLinkObserver.start()
			} else {
				updateDockIcon()
			}
		}
	}
	
	public private(set) static var animatedProgress = 0.0

	/**
	Reset the `progress` without animating.
	*/
	public static func resetProgress() {
		displayLinkObserver.stop()
		progress = 0
		animatedProgress = 0
		t = 0;
		updateDockIcon()
	}

	public enum Style {
		case bar
		case squircle(inset: Double? = nil, color: NSColor = .controlAccentColor)
		case circle(radius: Double, color: NSColor = .controlAccentColor)
		case badge(color: NSColor = .controlAccentColor, badgeValue: () -> Int)
		case pie(color: NSColor = .controlAccentColor)
		case custom(drawHandler: (_ rect: CGRect) -> Void)
	}

	public static var style = Style.bar

	// TODO: Make the progress smoother by also animating the steps between each call to `updateDockIcon()`
	private static func updateDockIcon() {
		dockContentView.needsDisplay = true;
		NSApp.dockTile.display()
	}
	
	private class ContentView: NSView {
		override func draw(_ dirtyRect: NSRect) {
			NSGraphicsContext.current?.imageInterpolation = .high
			
			NSApp.applicationIconImage?.draw(in: dirtyRect)
			
			// TODO: If the `progress` is 1, draw the full circle, then schedule another draw in n milliseconds to hide it
			if (animatedProgress <= 0 || animatedProgress >= 1) {
				return
			}

			switch style {
			case .bar:
				drawProgressBar(dirtyRect)
			case .squircle(let inset, let color):
				drawProgressSquircle(dirtyRect, inset: inset, color: color)
			case .circle(let radius, let color):
				drawProgressCircle(dirtyRect, radius: radius, color: color)
			case .badge(let color, let badgeValue):
				drawProgressBadge(dirtyRect, color: color, badgeLabel: badgeValue())
			case .pie(let color):
				drawProgressBadge(dirtyRect, color: color, badgeLabel: 0, isPie: true)
			case .custom(let drawingHandler):
				drawingHandler(dirtyRect)
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
		barProgress.size.width = barProgress.width * animatedProgress
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
		progressSquircle.progress = animatedProgress
		progressSquircle.render(in: cgContext)
	}

	private static func drawProgressCircle(_ dstRect: CGRect, radius: Double, color: NSColor) {
		guard let cgContext = NSGraphicsContext.current?.cgContext else {
			return
		}

		let progressCircle = ProgressCircleShapeLayer(radius: radius, center: dstRect.center)
		progressCircle.strokeColor = color.cgColor
		progressCircle.lineWidth = 4
		progressCircle.progress = animatedProgress
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
		progressCircle.progress = animatedProgress

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
		} else if absNumber < 10_000 {
			return "\(sign * Int(absNumber / 1000))k"
		} else {
			return "\(sign * 9)k+"
		}
	}

	private static func scaledBadgeFontSize(text: String) -> Double {
		switch text.count {
		case 1:
			return 30
		case 2:
			return 23
		case 3:
			return 19
		case 4:
			return 15
		default:
			return 0
		}
	}
}
