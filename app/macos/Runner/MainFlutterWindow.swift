import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow, FlutterAppLifecycleDelegate {
  /// Where the traffic lights go under Ferman's custom title bar, as the
  /// Flutter side reports it ("setTrafficLightLayout" on "ferman/window").
  private struct TrafficLightLayout {
    /// The height of Ferman's title bar (`--titlebar-h`, 38 pt).
    let titleBarHeight: CGFloat
    /// The distance from the window's leading edge to the first light.
    let leading: CGFloat
    /// The diameter of one light as the design draws it (12 pt).
    let diameter: CGFloat
    /// The gap between two lights (8 pt).
    let spacing: CGFloat
    /// Whether the UI runs right to left: the lights then sit at the right
    /// edge, close rightmost (a12-1ar).
    let rightToLeft: Bool
  }

  private var channel: FlutterMethodChannel?
  /// The "ferman/open" channel (ADR 0021, app/lib/platform/open_requests.dart).
  private var openChannel: FlutterMethodChannel?
  /// The files the system asked for before Dart called "ready".
  private var keptPaths: [String] = []
  /// Whether Dart called "ready": later files go out at once as "open".
  private var openReady = false
  private var trafficLights: TrafficLightLayout?
  private var observers: [NSObjectProtocol] = []
  private var appearanceObservation: NSKeyValueObservation?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Ferman draws its own title bar. Give the window the shape window_manager's
    // setTitleBarStyle(hidden) gives it before the window first shows: Dart
    // starts after the window is on screen, so the system title bar would
    // otherwise flash at every launch. window_manager's later call changes
    // nothing visible; the overrides below do nothing until the Flutter side
    // reports the traffic-light layout.
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    styleMask.insert(.fullSizeContentView)

    let channel = FlutterMethodChannel(
      name: "ferman/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel

    // Files from a double-click, "Open with" or the Dock reach the app
    // delegate, which hands them to its lifecycle delegates; a second launch
    // is routed to this instance by macOS itself.
    let openChannel = FlutterMethodChannel(
      name: "ferman/open",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    openChannel.setMethodCallHandler { [weak self] call, result in
      guard let self, call.method == "ready" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self.keptPaths)
      self.keptPaths = []
      self.openReady = true
    }
    self.openChannel = openChannel
    (NSApp.delegate as? FlutterAppDelegate)?.addApplicationLifecycleDelegate(self)

    // AppKit lays the title bar out again after these and puts the buttons
    // back at their default place; put them where Ferman's title bar wants
    // them. window_manager is the window's delegate, so notifications are
    // used instead of delegate methods.
    let relayout: [NSNotification.Name] = [
      NSWindow.didResizeNotification,
      NSWindow.didEndLiveResizeNotification,
      NSWindow.didBecomeKeyNotification,
      NSWindow.didResignKeyNotification,
      NSWindow.didBecomeMainNotification,
      NSWindow.didResignMainNotification,
      NSWindow.didChangeBackingPropertiesNotification,
    ]
    for name in relayout {
      observe(name) { $0.layoutTrafficLightsSoon() }
    }
    // While macOS animates out of full screen or into the Dock it draws the
    // buttons at their default place; hide them until they are moved back.
    observe(NSWindow.willExitFullScreenNotification) { $0.setTrafficLightsHidden(true) }
    observe(NSWindow.willMiniaturizeNotification) { $0.setTrafficLightsHidden(true) }
    observe(NSWindow.didExitFullScreenNotification) { $0.layoutTrafficLightsSoon(reveal: true) }
    observe(NSWindow.didDeminiaturizeNotification) { $0.layoutTrafficLightsSoon(reveal: true) }
    // A light or dark appearance change lays the title bar out again too.
    appearanceObservation = observe(\.effectiveAppearance) { window, _ in
      window.layoutTrafficLightsSoon()
    }

    super.awakeFromNib()
  }

  deinit {
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  // window_manager changes these when it hides or shows the title bar
  // (setTitleBarStyle) or sets the title; AppKit then lays the buttons out
  // again.
  override var styleMask: NSWindow.StyleMask {
    didSet { layoutTrafficLightsSoon() }
  }

  override var titlebarAppearsTransparent: Bool {
    didSet { layoutTrafficLightsSoon() }
  }

  override var title: String {
    didSet { layoutTrafficLightsSoon() }
  }

  private func observe(
    _ name: NSNotification.Name, _ action: @escaping (MainFlutterWindow) -> Void
  ) {
    observers.append(
      NotificationCenter.default.addObserver(forName: name, object: self, queue: .main) {
        [weak self] _ in
        if let self { action(self) }
      })
  }

  /// Takes the files the system asks Ferman to open: keeps them until Dart
  /// is ready (a cold launch), then sends each request as "open".
  func handleOpen(_ urls: [URL]) -> Bool {
    let paths = urls.filter(\.isFileURL).map(\.path)
    guard !paths.isEmpty else { return false }
    // macOS activates Ferman but leaves a minimized window in the Dock.
    if isMiniaturized {
      deminiaturize(nil)
    }
    if openReady {
      openChannel?.invokeMethod("open", arguments: paths)
    } else {
      keptPaths += paths
    }
    return true
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setTrafficLightLayout":
      guard let args = call.arguments as? [String: Any],
        let height = (args["titleBarHeight"] as? NSNumber)?.doubleValue,
        let leading = (args["leading"] as? NSNumber)?.doubleValue,
        let diameter = (args["diameter"] as? NSNumber)?.doubleValue,
        let spacing = (args["spacing"] as? NSNumber)?.doubleValue,
        height > 0, diameter > 0
      else {
        result(
          FlutterError(
            code: "bad-arguments",
            message: "setTrafficLightLayout needs titleBarHeight, leading, diameter and spacing",
            details: nil))
        return
      }
      trafficLights = TrafficLightLayout(
        titleBarHeight: CGFloat(height), leading: CGFloat(leading),
        diameter: CGFloat(diameter), spacing: CGFloat(spacing),
        rightToLeft: (args["rightToLeft"] as? Bool) ?? false)
      // The system tab bar would sit in the title bar container that the
      // layout resizes, under Ferman's own title bar.
      tabbingMode = .disallowed
      layoutTrafficLights()
      layoutTrafficLightsSoon()
      result(nil)
    case "titleBarDoubleClicked":
      performTitleBarDoubleClick()
      result(nil)
    case "doubleClickSettings":
      // The interval the user set in System Settings, in milliseconds. AppKit
      // has no double-click distance setting.
      result(["interval": Int((NSEvent.doubleClickInterval * 1000).rounded())])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Does what System Settings → Desktop & Dock → "Double-click a window's
  /// title bar to" says, as a native title bar would: zoom (the default,
  /// also for "Fill"), minimize, or nothing. Older systems store a
  /// minimize-on-double-click flag instead.
  private func performTitleBarDoubleClick() {
    let defaults = UserDefaults.standard
    switch defaults.string(forKey: "AppleActionOnDoubleClick") {
    case "Minimize"?:
      miniaturize(nil)
    case "None"?:
      break
    case .none where defaults.bool(forKey: "AppleMiniaturizeOnDoubleClick"):
      miniaturize(nil)
    default:
      zoom(nil)
    }
  }

  /// Lays the lights out now and again on the next run-loop turn, after
  /// AppKit has finished its own title bar layout. [reveal] shows lights
  /// hidden during a full-screen or Dock transition.
  private func layoutTrafficLightsSoon(reveal: Bool = false) {
    guard trafficLights != nil else { return }
    layoutTrafficLights()
    DispatchQueue.main.async { [weak self] in
      self?.layoutTrafficLights()
      if reveal { self?.setTrafficLightsHidden(false) }
    }
  }

  private func setTrafficLightsHidden(_ hidden: Bool) {
    guard trafficLights != nil,
      let container = standardWindowButton(.closeButton)?.superview?.superview
    else { return }
    container.isHidden = hidden
  }

  /// Centres the close, minimize and zoom buttons in Ferman's title bar and
  /// spaces them as the design draws its lights (FmWindow: 12 pt circles,
  /// 8 pt apart, 14 pt from the leading edge; at the right edge with close
  /// rightmost in right to left). Does nothing until the Flutter side
  /// reports the layout, while the native title bar shows, in full screen,
  /// where the title bar belongs to the system, or while a tab bar shows.
  private func layoutTrafficLights() {
    guard let layout = trafficLights,
      styleMask.contains(.fullSizeContentView),
      !styleMask.contains(.fullScreen),
      !(tabGroup?.isTabBarVisible ?? false),
      let close = standardWindowButton(.closeButton),
      let minimize = standardWindowButton(.miniaturizeButton),
      let zoom = standardWindowButton(.zoomButton),
      let container = close.superview?.superview
    else { return }

    // The buttons' container spans the top of the window; make it as tall
    // as Ferman's title bar so the buttons can be centred in it.
    var containerFrame = container.frame
    containerFrame.size.height = layout.titleBarHeight
    containerFrame.origin.y = frame.height - layout.titleBarHeight
    container.frame = containerFrame
    let width = container.bounds.width

    // A button's frame is a little larger than the circle it draws; place
    // the circles, not the frames, on whole device pixels (half points on a
    // Retina display).
    let scale = backingScaleFactor
    func aligned(_ value: CGFloat) -> CGFloat { (value * scale).rounded() / scale }
    for (index, button) in [close, minimize, zoom].enumerated() {
      let size = button.frame.size
      let offset = layout.leading + CGFloat(index) * (layout.diameter + layout.spacing)
      let circleStart = layout.rightToLeft ? width - offset - layout.diameter : offset
      let origin = NSPoint(
        x: aligned(circleStart - (size.width - layout.diameter) / 2),
        y: aligned((layout.titleBarHeight - size.height) / 2))
      button.setFrameOrigin(origin)
    }
  }
}
