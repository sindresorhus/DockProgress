// swift-tools-version:5.9
import PackageDescription

let package = Package(
	name: "DockProgress",
	platforms: [
		.macOS(.v10_15)
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
		)
	]
)
