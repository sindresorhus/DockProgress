import Cocoa

public final class DockProgress {
	private static let appIcon = NSApp.applicationIconImage!
	private static var previousProgressValue: Double = 0
	private static var progressObserver: NSKeyValueObservation?

	private static var dockImageView = with(NSImageView()) {
		NSApp.dockTile.contentView = $0
	}

	public static var progress: Progress? {
		didSet {
			if let progress = progress {
				progressObserver = progress.observe(\.fractionCompleted) { object, _ in
					progressValue = object.fractionCompleted
				}
			}
		}
	}

	public static var progressValue: Double = 0 {
		didSet {
			if previousProgressValue == 0 || (progressValue - previousProgressValue).magnitude > 0.01 {
				previousProgressValue = progressValue
				updateDockIcon()
			}
		}
	}

	public enum ProgressStyle {
		case bar
		/// TODO: Make `color` optional when https://github.com/apple/swift-evolution/blob/master/proposals/0155-normalize-enum-case-representation.md is shipping in Swift
		case circle(radius: Double, color: NSColor)
		case badge(color: NSColor, badgeLabel: String)
		case custom(drawHandler: (_ rect: CGRect) -> Void)
	}

	public static var style: ProgressStyle = .bar

	/// TODO: Make the progress smoother by also animating the steps between each call to `updateDockIcon()`
	private static func updateDockIcon() {
		/// TODO: If the `progressValue` is 1, draw the full circle, then schedule another draw in n milliseconds to hide it
		let icon = (0..<1).contains(self.progressValue) ? self.draw() : appIcon
		DispatchQueue.main.async {
			/// TODO: Make this better by drawing in the `contentView` directly instead of using an image
			dockImageView.image = icon
			NSApp.dockTile.display()
		}
	}

	private static func draw() -> NSImage {
		return NSImage(size: appIcon.size, flipped: false) { dstRect in
			NSGraphicsContext.current?.imageInterpolation = .high
			self.appIcon.draw(in: dstRect)

			switch self.style {
			case .bar:
				self.drawProgressBar(dstRect)
			case let .circle(radius, color):
				self.drawProgressCircle(dstRect, radius: radius, color: color)
			case let .badge(color, badgeLabel):
				self.drawProgressBadge(dstRect, badgeLabel: badgeLabel, color: color)
			case let .custom(drawingHandler):
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
		NSColor.white.with(alpha: 0.8).set()
		roundedRect(bar)

		let barInnerBg = bar.insetBy(dx: 0.5, dy: 0.5)
		NSColor.black.with(alpha: 0.8).set()
		roundedRect(barInnerBg)

		var barProgress = bar.insetBy(dx: 1, dy: 1)
		barProgress.size.width = barProgress.width * CGFloat(progressValue)
		NSColor.white.set()
		roundedRect(barProgress)
	}

	private static func drawProgressCircle(_ dstRect: CGRect, radius: Double, color: NSColor) {
		guard let cgContext = NSGraphicsContext.current?.cgContext else {
			return
		}

		let progressCircle = ProgressCircleShapeLayer(radius: radius, center: dstRect.center)
		progressCircle.strokeColor = color.cgColor
		progressCircle.lineWidth = 4
		progressCircle.cornerRadius = 3
		progressCircle.progress = progressValue
		progressCircle.render(in: cgContext)
	}
	
	private static func drawProgressBadge(_ dstRect: CGRect, badgeLabel: String, color: NSColor) {
		guard let cgContext = NSGraphicsContext.current?.cgContext else {
			return
		}

		let radius = dstRect.width / 4.8
		let newCenter = CGPoint(x: dstRect.maxX - radius - 4, y: dstRect.minY + radius + 4)

		// Background
		let badge = ProgressCircleShapeLayer(radius: Double(radius), center: newCenter)
		badge.fillColor = CGColor(red: 0.94, green: 0.96, blue: 1, alpha: 1)

		// Progress circle
		let lineWidth: CGFloat = 6
		let innerRadius = Double(radius) - Double(lineWidth / 2)
		let progressCircle = ProgressCircleShapeLayer(radius: innerRadius, center: newCenter)
		progressCircle.strokeColor = color.cgColor
		progressCircle.lineWidth = lineWidth
		progressCircle.lineCap = .square
		progressCircle.progress = progressValue

		// Label
		let dimension = badge.bounds.height - 5
		let rect = CGRect(origin: progressCircle.bounds.origin, size: CGSize(width: dimension, height: dimension))
		let textLayer = VerticallyCenteredTextLayer(frame: rect, center: newCenter)
		textLayer.foregroundColor = CGColor(red: 0.23, green: 0.23, blue: 0.24, alpha: 1)
		textLayer.string = badgeLabel
		textLayer.alignmentMode = .center
		textLayer.truncationMode = .end
		textLayer.font = NSFont.helveticaNeueBold
		textLayer.fontSize = 23
		textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2

		badge.addSublayer(textLayer)
		badge.addSublayer(progressCircle)
		badge.render(in: cgContext)
	}
}
