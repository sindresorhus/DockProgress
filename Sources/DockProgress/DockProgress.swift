import Cocoa

public enum DockProgress {
	private static var previousProgress: Double = 0
	private static var progressObserver: NSKeyValueObservation?
	private static var finishedObserver: NSKeyValueObservation?

	private static let dockImageView = with(NSImageView()) {
		NSApp.dockTile.contentView = $0
	}

	public static weak var progressInstance: Progress? {
		didSet {
			guard let progressInstance = progressInstance else {
				progressObserver = nil
				finishedObserver = nil
				resetProgress()
				return
			}

			progressObserver = progressInstance.observe(\.fractionCompleted) { sender, _ in
				guard
					!sender.isCancelled,
					!sender.isFinished
				else {
					return
				}

				progress = sender.fractionCompleted
			}

			finishedObserver = progressInstance.observe(\.isFinished) { sender, _ in
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

	public static var progress: Double = 0 {
		didSet {
			if previousProgress == 0 || (progress - previousProgress).magnitude > 0.01 {
				previousProgress = progress
				updateDockIcon()
			}
		}
	}

	/// Reset the `progress` without animating.
	public static func resetProgress() {
		progress = 0
		previousProgress = 0
		updateDockIcon()
	}

	public enum ProgressStyle {
		case bar
		case squircle(inset: Double? = nil, color: NSColor = .controlAccentColorPolyfill)
		case circle(radius: Double, color: NSColor = .controlAccentColorPolyfill)
		case badge(color: NSColor = .controlAccentColorPolyfill, badgeValue: () -> Int)
		case custom(drawHandler: (_ rect: CGRect) -> Void)
	}

	public static var style: ProgressStyle = .bar

	// TODO: Make the progress smoother by also animating the steps between each call to `updateDockIcon()`
	private static func updateDockIcon() {
		// TODO: If the `progress` is 1, draw the full circle, then schedule another draw in n milliseconds to hide it
		DispatchQueue.main.async {
			guard let appIcon = NSApp.applicationIconImage else {
				return
			}

			let icon = (0..<1).contains(progress) ? draw(appIcon) : appIcon
			// TODO: Make this better by drawing in the `contentView` directly instead of using an image
			dockImageView.image = icon
			NSApp.dockTile.display()
		}
	}

	private static func draw(_ appIcon: NSImage) -> NSImage {
		NSImage(size: appIcon.size, flipped: false) { dstRect in
			NSGraphicsContext.current?.imageInterpolation = .high
			appIcon.draw(in: dstRect)

			switch self.style {
			case .bar:
				self.drawProgressBar(dstRect)
			case .squircle(let inset, let color):
				self.drawProgressSquircle(dstRect, inset: inset, color: color)
			case .circle(let radius, let color):
				self.drawProgressCircle(dstRect, radius: radius, color: color)
			case .badge(let color, let badgeValue):
				self.drawProgressBadge(dstRect, color: color, badgeLabel: badgeValue())
			case .custom(let drawingHandler):
				drawingHandler(dstRect)
			}

			return true
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
		barProgress.size.width = barProgress.width * CGFloat(progress)
		NSColor.white.set()
		roundedRect(barProgress)
	}

	private static func drawProgressSquircle(_ dstRect: CGRect, inset: Double? = nil, color: NSColor) {
		guard let cgContext = NSGraphicsContext.current?.cgContext else {
			return
		}

		let defaultInset: CGFloat = 14.4

		var rect = dstRect.insetBy(dx: defaultInset, dy: defaultInset)

		if let inset = inset {
			rect = rect.insetBy(dx: CGFloat(inset), dy: CGFloat(inset))
		}

		let progressSquircle = ProgressSquircleShapeLayer(rect: rect)
		progressSquircle.strokeColor = color.cgColor
		progressSquircle.lineWidth = 5
		progressSquircle.progress = progress
		progressSquircle.render(in: cgContext)
	}

	private static func drawProgressCircle(_ dstRect: CGRect, radius: Double, color: NSColor) {
		guard let cgContext = NSGraphicsContext.current?.cgContext else {
			return
		}

		let progressCircle = ProgressCircleShapeLayer(radius: radius, center: dstRect.center)
		progressCircle.strokeColor = color.cgColor
		progressCircle.lineWidth = 4
		progressCircle.progress = progress
		progressCircle.render(in: cgContext)
	}

	private static func drawProgressBadge(_ dstRect: CGRect, color: NSColor, badgeLabel: Int) {
		guard let cgContext = NSGraphicsContext.current?.cgContext else {
			return
		}

		let radius = dstRect.width / 4.8
		let newCenter = CGPoint(x: dstRect.maxX - radius - 4, y: dstRect.minY + radius + 4)

		// Background
		let badge = ProgressCircleShapeLayer(radius: Double(radius), center: newCenter)
		badge.fillColor = CGColor(red: 0.94, green: 0.96, blue: 1, alpha: 1)
		badge.shadowColor = .black
		badge.shadowOpacity = 0.3
		badge.masksToBounds = false
		badge.shadowOffset = CGSize(width: -1, height: 1)
		badge.shadowPath = badge.path

		// Progress circle
		let lineWidth: CGFloat = 6
		let innerRadius = radius - lineWidth / 2
		let progressCircle = ProgressCircleShapeLayer(radius: Double(innerRadius), center: newCenter)
		progressCircle.strokeColor = color.cgColor
		progressCircle.lineWidth = lineWidth
		progressCircle.lineCap = .butt
		progressCircle.progress = progress

		// Label
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

	private static func scaledBadgeFontSize(text: String) -> CGFloat {
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
