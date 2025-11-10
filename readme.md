# DockProgress

> Show progress in your app's Dock icon

## Requirements

macOS 12+

## Install

Add `https://github.com/sindresorhus/DockProgress` in the [“Swift Package Manager” tab in Xcode](https://developer.apple.com/documentation/xcode/adding_package_dependencies_to_your_app).

*Latest version: 5.0.1*

## API

[See the API docs.](https://swiftpackageindex.com/sindresorhus/DockProgress/documentation/dockprogress/dockprogress)

## Usage

### Manually set the progress

```swift
import DockProgress

foo.onUpdate = { progress in
	DockProgress.progress = progress
}
```

### Specify a [`Progress` instance](https://developer.apple.com/documentation/foundation/progress)

```swift
import Foundation
import DockProgress

let progress = Progress(totalUnitCount: 1)
progress.becomeCurrent(withPendingUnitCount: 1)

DockProgress.progressInstance = progress
```

The given `Progress` instance is weakly stored. It's up to you to retain it.

## Styles

Includes built-in styles (bar, squircle, circle, badge, pie) plus support for custom styles using SwiftUI views or Canvas drawing.

See the example app in the Xcode project for demonstrations.

### Custom Styles

Create custom progress indicators with:

1. **SwiftUI View**: `.customView { progress in /* return any View */ }` - Maximum flexibility with any SwiftUI view
2. **SwiftUI Canvas**: `.customCanvas { context, size, progress in /* draw on canvas */ }` - High-performance custom drawing
3. **Legacy Core Graphics**: `.custom(drawHandler: (_ rect: CGRect) -> Void)` - Direct Core Graphics drawing (backward compatibility)

### Bar

![](screenshot-bar.gif)

```swift
import DockProgress

DockProgress.style = .bar
```

This is the default.

### Squircle

<img src="screenshot-squircle.gif" width="158" height="158">

```swift
import DockProgress

DockProgress.style = .squircle(color: .white.opacity(0.5))
```

Fits perfectly around macOS app icons by default. Use the `inset` parameter for adjustments if needed.

### Circle

![](screenshot-circle.gif)

```swift
import DockProgress

DockProgress.style = .circle(radius: 55, color: .blue)
```

### Badge

![](screenshot-badge.gif)

```swift
import DockProgress

DockProgress.style = .badge(color: .blue, badgeValue: { getDownloadCount() })
```

Large numbers are shortened: `1012` → `1k`, `10000` → `9k+`.

**Note:** `badgeValue` is for counts (downloads, files, etc.), not percentages.

### Pie

<img src="screenshot-pie.gif" width="150" height="150">

```swift
import DockProgress

DockProgress.style = .pie(color: .blue)
```

## Related

- [Defaults](https://github.com/sindresorhus/Defaults) - Swifty and modern UserDefaults
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Add user-customizable global keyboard shortcuts to your macOS app
- [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin) - Add "Launch at Login" functionality to your macOS app
- [More…](https://github.com/search?q=user%3Asindresorhus+language%3Aswift+archived%3Afalse&type=repositories)
