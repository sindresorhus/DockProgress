# DockProgress

> Show progress in your app's Dock icon

<img src="screenshot.gif" width="485">

This package is used in production by the [Gifski app](https://github.com/sindresorhus/gifski-app). You might also like some of my [other apps](https://sindresorhus.com/#apps).


## Requirements

- macOS 10.12+
- Xcode 9.3+
- Swift 4.1+


## Install

#### SPM

```swift
.package(url: "https://github.com/sindresorhus/DockProgress", from: "1.0.0")
```

#### Carthage

```
github "sindresorhus/DockProgress"
```

<a href="https://www.patreon.com/sindresorhus">
	<img src="https://c5.patreon.com/external/logo/become_a_patron_button@2x.png" width="160">
</a>


## Usage

### Manually set the progress

```swift
import Cocoa
import DockProgress

foo.onUpdate = { progress in
	DockProgress.progressValue = progress
}
```

### Specify a [`Progress`](https://developer.apple.com/documentation/foundation/progress) instance

```swift
import Cocoa
import DockProgress

let progress = Progress(totalUnitCount: 1)
progress?.becomeCurrent(withPendingUnitCount: 1)

DockProgress.progress = progress
```


## Styles

It comes with two styles. PR welcome for more.

You can also draw a custom progress with `.custom(drawHandler: (_ rect: CGRect) -> Void)`.

### Bar

![](screenshot-bar.gif)

```swift
import DockProgress

DockProgress.style = .bar
```

This is the default.

### Circle

![](screenshot-circle.gif)

```swift
import DockProgress

DockProgress.style = .circle(radius: 55, color: .systemBlue)
```

Make sure to set a `radius` that matches your app icon.


## Related

- [Defaults](https://github.com/sindresorhus/Defaults) - Swifty and modern UserDefaults
- [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin) - Add "Launch at Login" functionality to your macOS app


## License

MIT © [Sindre Sorhus](https://sindresorhus.com)
