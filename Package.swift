// swift-tools-version:4.2
import PackageDescription

let package = Package(
	name: "DockProgress",
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
