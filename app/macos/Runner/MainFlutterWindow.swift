import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

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
  /// The "ferman/files" channel: bookmarks of the files the user granted.
  private var filesChannel: FlutterMethodChannel?
  /// The files whose security-scoped access has started, by path, with the
  /// resolved URL that holds it: only that URL can stop it.
  private var accessed: [String: URL] = [:]
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

    // Security-scoped bookmarks reach a file again after a restart under the
    // App Sandbox (Q18, ADR 0021, app/lib/platform/file_access.dart).
    let filesChannel = FlutterMethodChannel(
      name: "ferman/files",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    filesChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.handleFiles(call, result: result)
    }
    self.filesChannel = filesChannel

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

  /// The name in Dart's `SwapFailure` of why "swapIn" failed.
  private static func swapFailure(_ error: NSError) -> String {
    // Foundation often wraps the system's reason in a general write error.
    if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError,
      underlying.domain == NSPOSIXErrorDomain
    {
      switch Int32(underlying.code) {
      case EBUSY: return "locked"
      case EACCES, EPERM, EROFS: return "permission"
      case ENOSPC: return "diskFull"
      case ENOENT: return "volumeGone"
      default: break
      }
    }
    guard error.domain == NSCocoaErrorDomain else { return "other" }
    switch error.code {
    case NSFileWriteNoPermissionError, NSFileReadNoPermissionError, NSFileWriteVolumeReadOnlyError:
      return "permission"
    case NSFileWriteOutOfSpaceError:
      return "diskFull"
    case NSFileLockingError:
      return "locked"
    case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
      return "volumeGone"
    default:
      return "other"
    }
  }

  /// "bookmark" makes a security-scoped bookmark (base64) of a file Ferman
  /// may read now; "access" resolves one, starts access to its file once
  /// until "release" ends it (its document closed, B029) and answers with
  /// its path and, when it went stale, a renewed bookmark. Resolving never
  /// mounts a volume or shows UI, so a file on a server that is not
  /// connected is missing at once (a1-9e), as is a file in the Trash.
  /// "show" selects a file in Finder (a1-9b): the sandbox lets Finder show
  /// a file Ferman may read, which every file it opened is.
  /// "staging" names the item-replacement directory on the volume of a file
  /// chosen in the save panel, where the engine writes and verifies the new
  /// file first; "swapIn" puts that file in place with `replaceItemAt`, or
  /// moves it there when there is none yet, and removes the directory
  /// (ADR 0008, B110): the sandbox grants the chosen file, not its folder.
  /// "discardStaging" removes such a directory, if empty, after a refused save.
  /// "pdfHandler" names the app that opens PDF files and says whether it is
  /// Ferman; "makeDefault" asks macOS, which asks the person, to make
  /// Ferman that app (B080, app/lib/platform/default_app.dart).
  private func handleFiles(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "bookmark":
      guard let path = call.arguments as? String,
        let data = try? URL(fileURLWithPath: path).bookmarkData(
          options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
      else {
        result(nil)
        return
      }
      result(data.base64EncodedString())
    case "access":
      guard let text = call.arguments as? String,
        let data = Data(base64Encoded: text)
      else {
        result(nil)
        return
      }
      var stale = false
      guard
        let url = try? URL(
          resolvingBookmarkData: data,
          options: [.withSecurityScope, .withoutUI, .withoutMounting], relativeTo: nil,
          bookmarkDataIsStale: &stale),
        !url.pathComponents.contains(".Trash")
      else {
        result(nil)
        return
      }
      if accessed[url.path] == nil, url.startAccessingSecurityScopedResource() {
        accessed[url.path] = url
      }
      let renewed =
        stale
        ? (try? url.bookmarkData(
          options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil))?
          .base64EncodedString() : nil
      result(["path": url.path, "renewed": renewed as Any])
    case "release":
      if let path = call.arguments as? String, let url = accessed.removeValue(forKey: path) {
        url.stopAccessingSecurityScopedResource()
      }
      result(nil)
    case "show":
      guard let path = call.arguments as? String,
        FileManager.default.fileExists(atPath: path)
      else {
        result(false)
        return
      }
      NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
      result(true)
    case "staging":
      // Unsandboxed, the engine writes beside the file as on the other systems.
      guard ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil,
        let path = call.arguments as? String
      else {
        result(nil)
        return
      }
      // Only the volume counts, and a file that does not exist yet names none.
      let near = URL(fileURLWithPath: path).resolvingSymlinksInPath()
      guard
        let url = try? FileManager.default.url(
          for: .itemReplacementDirectory, in: .userDomainMask,
          appropriateFor: FileManager.default.fileExists(atPath: path)
            ? near : near.deletingLastPathComponent(), create: true)
      else {
        result(nil)
        return
      }
      result(url.path)
    case "swapIn":
      guard let arguments = call.arguments as? [String: Any],
        let staged = arguments["staged"] as? String,
        let path = arguments["path"] as? String
      else {
        result("other")
        return
      }
      let stagedURL = URL(fileURLWithPath: staged)
      // A symbolic link stays and the file it names is replaced, as in the engine's own save.
      let named = URL(fileURLWithPath: path)
      let isLink = (try? named.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink
      let target = isLink == true ? named.resolvingSymlinksInPath() : named
      let manager = FileManager.default
      var failure: Any = true
      do {
        if manager.fileExists(atPath: target.path) {
          _ = try manager.replaceItemAt(target, withItemAt: stagedURL)
        } else {
          try manager.moveItem(at: stagedURL, to: target)
        }
      } catch {
        let error = error as NSError
        failure = Self.swapFailure(error)
        // Foundation's rare failure after moving the original aside: it goes back.
        if let aside = error.userInfo["NSFileOriginalItemLocationKey"] as? URL,
          !manager.fileExists(atPath: target.path)
        {
          try? manager.moveItem(at: aside, to: target)
        }
      }
      // The staged file and its directory, never recursively: the original may be in there.
      try? manager.removeItem(at: stagedURL)
      _ = rmdir(stagedURL.deletingLastPathComponent().path)
      result(failure)
    case "discardStaging":
      if let directory = call.arguments as? String {
        _ = rmdir(directory)
      }
      result(nil)
    case "openUrl":
      // Only what the engine offers, after the app's prompt (G145); the OS opens it.
      guard let text = call.arguments as? String, let url = URL(string: text),
        let scheme = url.scheme?.lowercased(), ["http", "https", "mailto"].contains(scheme)
      else {
        result(false)
        return
      }
      result(NSWorkspace.shared.open(url))
    case "pdfHandler":
      guard let url = NSWorkspace.shared.urlForApplication(toOpen: .pdf) else {
        result(nil)
        return
      }
      result([
        "name": FileManager.default.displayName(atPath: url.path),
        "ferman": Bundle(url: url)?.bundleIdentifier == Bundle.main.bundleIdentifier,
      ])
    case "makeDefault":
      NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: .pdf) {
        error in
        DispatchQueue.main.async { result(error == nil) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
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
