import Testing
import SwiftUI
@testable import DockProgress

@Suite("DockProgress Tests")
@MainActor
struct DockProgressTests {
	init() async throws {
		DockProgress.resetProgress()
	}

	// MARK: - Core Functionality Tests

	@Test("Progress values are tracked correctly")
	func progressTracking() {
		// Basic progress setting
		DockProgress.progress = 0.5
		#expect(DockProgress.progress == 0.5)

		// Edge cases
		DockProgress.progress = -0.5
		#expect(DockProgress.progress == -0.5)
		#expect(DockProgress.displayedProgress == 0) // Should clamp display to 0

		DockProgress.progress = 1.5
		#expect(DockProgress.progress == 1.5)

		DockProgress.progress = 0
		#expect(DockProgress.progress == 0)

		DockProgress.progress = 1
		#expect(DockProgress.progress == 1)
	}

	@Test("Progress reset works")
	func progressReset() {
		DockProgress.progress = 0.75
		DockProgress.resetProgress()
		#expect(DockProgress.progress == 0)
		#expect(DockProgress.displayedProgress == 0)
	}

	@Test("Progress instance integration")
	func progressInstance() {
		let progress = Progress(totalUnitCount: 100)
		progress.completedUnitCount = 50

		DockProgress.progressInstance = progress
		#expect(DockProgress.progressInstance != nil)
		#expect(DockProgress.progressInstance?.fractionCompleted == 0.5)

		progress.completedUnitCount = 75
		#expect(DockProgress.progressInstance?.fractionCompleted == 0.75)

		DockProgress.progressInstance = nil
		#expect(DockProgress.progressInstance == nil)
	}

	// MARK: - Style Tests

	@Test("Built-in styles work correctly")
	func builtInStyles() {
		let testData: [(DockProgress.Style, String, Double)] = [
			(.bar, "bar", 0.3),
			(.squircle(color: .blue), "squircle", 0.5),
			(.squircle(inset: 5, color: .red), "squircle with inset", 0.6),
			(.circle(radius: 30, color: .green), "circle", 0.7),
			(.badge(color: .purple) { 42 }, "badge", 0.8),
			(.pie(color: .orange), "pie", 0.9)
		]

		for (style, name, progress) in testData {
			DockProgress.style = style
			DockProgress.progress = progress
			#expect(DockProgress.progress == progress, "Style \(name) should maintain progress value")
		}
	}

	@Test("Custom view style works")
	func customViewStyle() {
		let customView = { @MainActor @Sendable (progress: Double) -> AnyView in
			AnyView(
				Circle()
					.trim(from: 0, to: progress)
					.stroke(Color.blue, lineWidth: 4)
					.frame(width: 100, height: 100)
			)
		}

		DockProgress.style = .customView(customView)
		DockProgress.progress = 0.5
		#expect(DockProgress.progress == 0.5)
	}

	@Test("Custom canvas style works")
	func customCanvasStyle() {
		DockProgress.style = .customCanvas { context, size, progress in
			let rect = CGRect(origin: .zero, size: size).insetBy(dx: 10, dy: 10)
			context.fill(
				Path(ellipseIn: rect),
				with: .color(.blue.opacity(progress))
			)
		}

		DockProgress.progress = 0.75
		#expect(DockProgress.progress == 0.75)
	}

	@Test("Style transitions work smoothly")
	func styleTransitions() {
		// Transition between different style types
		DockProgress.style = .bar
		DockProgress.progress = 0.2
		#expect(DockProgress.progress == 0.2)

		DockProgress.style = .customView { _ in Rectangle().fill(Color.red) }
		DockProgress.progress = 0.4
		#expect(DockProgress.progress == 0.4)

		DockProgress.style = .circle(radius: 30, color: .blue)
		DockProgress.progress = 0.8
		#expect(DockProgress.progress == 0.8)
	}

	@Test("Reset removes hosting view before rendering a new style")
	func hostingViewResetsBetweenCycles() {
		DockProgress.style = .bar
		DockProgress.testingRenderCurrentStyle(progress: 0.5)
		#expect(DockProgress.testingHasActiveHostingView)

		DockProgress.resetProgress()
		#expect(!DockProgress.testingHasActiveHostingView)

		DockProgress.style = .customView { progress in
			AnyView(
				Text("\(Int(progress * 100))%")
					.font(.system(size: 14, weight: .semibold))
			)
		}
		DockProgress.testingRenderCurrentStyle(progress: 0.4)
		#expect(DockProgress.testingHasActiveHostingView)

		DockProgress.resetProgress()
	}

	@Test("Hosting view clears when Dock content hides")
	func hostingViewClearsWhenHidden() {
		DockProgress.style = .bar
		DockProgress.testingRenderCurrentStyle(progress: 0.6)
		#expect(DockProgress.testingHasActiveHostingView)

		DockProgress.testingRenderCurrentStyle(progress: 0)
		#expect(!DockProgress.testingHasActiveHostingView)

		DockProgress.testingRenderCurrentStyle(progress: 1)
		#expect(!DockProgress.testingHasActiveHostingView)

		DockProgress.resetProgress()
	}

	// MARK: - Utility Function Tests

	@Test("Kilo short string formatting")
	func kiloFormatting() {
		#expect(DockProgress.kiloShortStringFromInt(number: 999) == "999")
		#expect(DockProgress.kiloShortStringFromInt(number: 1000) == "1k")
		#expect(DockProgress.kiloShortStringFromInt(number: 1100) == "1k")
		#expect(DockProgress.kiloShortStringFromInt(number: 2500) == "2k")
		#expect(DockProgress.kiloShortStringFromInt(number: 10000) == "9k+")
		#expect(DockProgress.kiloShortStringFromInt(number: -1500) == "-1k")
		#expect(DockProgress.kiloShortStringFromInt(number: 0) == "0")
	}

	@Test("Badge font size scaling")
	func badgeFontScaling() {
		#expect(DockProgress.scaledBadgeFontSize(text: "1") == 30)
		#expect(DockProgress.scaledBadgeFontSize(text: "12") == 23)
		#expect(DockProgress.scaledBadgeFontSize(text: "123") == 19)
		#expect(DockProgress.scaledBadgeFontSize(text: "1234") == 15)
		#expect(DockProgress.scaledBadgeFontSize(text: "12345") == 0)
	}

	// MARK: - Extension Tests

	@Test("Path extensions")
	func pathExtensions() {
		let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
		let squirclePath = Path.squircle(in: rect)
		#expect(!squirclePath.isEmpty)

		let center = CGPoint(x: 50, y: 50)
		let circlePath = Path.progressCircle(center: center, radius: 25)
		#expect(!circlePath.isEmpty)
	}

	@Test("CGRect extensions")
	func cgRectExtensions() {
		let center = CGPoint(x: 50, y: 50)
		let radius: Double = 25
		let circleRect = CGRect.circleRect(center: center, radius: radius)

		#expect(abs(circleRect.midX - center.x) < 0.001)
		#expect(abs(circleRect.midY - center.y) < 0.001)
		#expect(abs(circleRect.width - radius * 2) < 0.001)
		#expect(abs(circleRect.height - radius * 2) < 0.001)
	}

	// MARK: - Integration Tests

	@Test("SwiftUI view integration")
	func swiftUIIntegration() {
		struct TestProgressView: View {
			let progress: Double
			var body: some View {
				ProgressView(value: progress)
					.progressViewStyle(.circular)
			}
		}

		DockProgress.style = .customView { progress in
			TestProgressView(progress: progress)
		}

		DockProgress.progress = 0.3
		#expect(DockProgress.progress == 0.3)
	}

	@Test("Complex custom view rendering")
	func complexCustomView() {
		struct ComplexView: View {
			let progress: Double
			var body: some View {
				ZStack {
					Circle()
						.stroke(Color.gray.opacity(0.3), lineWidth: 10)
					Circle()
						.trim(from: 0, to: progress)
						.stroke(
							LinearGradient(
								colors: [.blue, .purple],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							),
							style: StrokeStyle(lineWidth: 10, lineCap: .round)
						)
						.rotationEffect(.degrees(-90))
					Text("\(Int(progress * 100))%")
						.font(.system(size: 16, weight: .bold))
				}
				.frame(width: 100, height: 100)
			}
		}

		DockProgress.style = .customView { progress in
			ComplexView(progress: progress)
		}

		DockProgress.progress = 0.65
		#expect(DockProgress.progress == 0.65)
	}
}
