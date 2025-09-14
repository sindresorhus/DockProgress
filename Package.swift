// swift-tools-version:6.1
import PackageDescription

let package = Package(
	name: "DockProgress",
	platforms: [
		.macOS(.v12)
	],
	products: [
		.library(
			name: "DockProgress",
			targets: [
				"DockProgress"
			]
		)
	],
	targets: [
		.target(
			name: "DockProgress"
		),
		.testTarget(
			name: "DockProgressTests",
			dependencies: ["DockProgress"]
		)
	]
)
