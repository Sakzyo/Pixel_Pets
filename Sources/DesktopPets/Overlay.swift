import AppKit
import ImageIO
import QuartzCore

struct SpriteAnimation {
    let frames: [CGImage]
    let durations: [TimeInterval]

    static func load(_ url: URL) -> SpriteAnimation? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        var frames: [CGImage] = []
        var durations: [TimeInterval] = []
        for index in 0..<CGImageSourceGetCount(source) {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let duration = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double)
                ?? 0.125
            frames.append(image)
            durations.append(max(0.02, duration))
        }
        return frames.isEmpty ? nil : SpriteAnimation(frames: frames, durations: durations)
    }
}

@MainActor
final class SpriteCache {
    private var items: [URL: SpriteAnimation] = [:]
    private var pending: [URL: [(SpriteAnimation?) -> Void]] = [:]
    private let decodeQueue = DispatchQueue(label: "DesktopPets.SpriteDecode", qos: .userInitiated)

    func request(_ url: URL, onReady: @escaping (SpriteAnimation?) -> Void) {
        if let item = items[url] { onReady(item); return }
        if pending[url] != nil { pending[url]?.append(onReady); return }
        pending[url] = [onReady]
        decodeQueue.async { [weak self] in
            let decoded = SpriteAnimation.load(url)
            DispatchQueue.main.async {
                guard let self else { return }
                if let decoded { self.items[url] = decoded }
                for callback in self.pending.removeValue(forKey: url) ?? [] { callback(decoded) }
            }
        }
    }

    func retain(for pets: [PetRecord]) {
        let folders = Set(pets.map { Bundle.main.resourceURL?.appendingPathComponent("Assets/\($0.species)").path })
        items = items.filter { folders.contains($0.key.deletingLastPathComponent().path) }
    }
}

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PetSpriteView: NSView {
    var onFeed: (() -> Void)?
    var onHover: ((Bool) -> Void)?
    var onManage: (() -> Void)?
    var onHide: (() -> Void)?
    private let spriteLayer = CALayer()
    private let reactionLayer = CATextLayer()
    private var tracking: NSTrackingArea?
    private var animation: SpriteAnimation?
    private var frameIndex = 0
    private var nextFrameAt: TimeInterval = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        spriteLayer.contentsGravity = .resizeAspect
        spriteLayer.magnificationFilter = .nearest
        spriteLayer.minificationFilter = .nearest
        layer?.addSublayer(spriteLayer)
        reactionLayer.string = "♥"
        reactionLayer.fontSize = 17
        reactionLayer.alignmentMode = .center
        reactionLayer.foregroundColor = NSColor.systemPink.cgColor
        reactionLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        reactionLayer.opacity = 0
        layer?.addSublayer(reactionLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        spriteLayer.frame = bounds
        reactionLayer.frame = CGRect(x: bounds.midX - 12, y: bounds.maxY - 22, width: 24, height: 22)
    }

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(area)
        tracking = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
    override func mouseDown(with event: NSEvent) { onFeed?() }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let feed = NSMenuItem(title: "Feed", action: #selector(feedFromMenu), keyEquivalent: "")
        feed.target = self
        menu.addItem(feed)
        let hide = NSMenuItem(title: "Hide", action: #selector(hideFromMenu), keyEquivalent: "")
        hide.target = self
        menu.addItem(hide)
        let manage = NSMenuItem(title: "Manage Pets", action: #selector(manageFromMenu), keyEquivalent: "")
        manage.target = self
        menu.addItem(manage)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func feedFromMenu() { onFeed?() }
    @objc private func hideFromMenu() { onHide?() }
    @objc private func manageFromMenu() { onManage?() }

    func setAnimation(_ value: SpriteAnimation?, now: TimeInterval) {
        guard let value else { return }
        animation = value
        frameIndex = 0
        nextFrameAt = now + value.durations[0]
        displayFrame(value.frames[0])
    }

    func advance(now: TimeInterval) {
        guard let animation, animation.frames.count > 1, now >= nextFrameAt else { return }
        frameIndex = (frameIndex + 1) % animation.frames.count
        nextFrameAt = now + animation.durations[frameIndex]
        displayFrame(animation.frames[frameIndex])
    }

    func face(left: Bool) {
        spriteLayer.transform = CATransform3DMakeScale(left ? -1 : 1, 1, 1)
    }

    func showFeedReaction() {
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 1, 1, 0]
        fade.keyTimes = [0, 0.2, 0.65, 1]
        fade.duration = 1
        reactionLayer.add(fade, forKey: "feed")
    }

    private func displayFrame(_ frame: CGImage) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        spriteLayer.contents = frame
        CATransaction.commit()
    }
}

@MainActor
final class PetProjection {
    let panel: PetPanel
    let view: PetSpriteView
    let petID: UUID
    var x: CGFloat
    var behavior = PetBehaviorEngine(now: ProcessInfo.processInfo.systemUptime)
    var currentAnimation = ""

    init(petID: UUID, size: CGFloat, x: CGFloat) {
        self.petID = petID
        self.x = x
        panel = PetPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        if #available(macOS 15.0, *) { panel.collectionBehavior.insert(.canJoinAllApplications) }
        panel.animationBehavior = .none
        view = PetSpriteView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        panel.contentView = view
    }

    func close() { panel.orderOut(nil); panel.close() }
}

@MainActor
final class BallProjection {
    let panel: PetPanel
    var x: CGFloat
    var y: CGFloat
    var velocity: CGFloat = 0
    var bounces = 0
    let createdAt = ProcessInfo.processInfo.systemUptime

    init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
        panel = PetPanel(contentRect: NSRect(x: x - 8, y: y - 8, width: 16, height: 16),
                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        if #available(macOS 15.0, *) { panel.collectionBehavior.insert(.canJoinAllApplications) }
        panel.ignoresMouseEvents = true
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 16, height: 16))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        let ball = CALayer()
        ball.frame = CGRect(x: 1, y: 1, width: 14, height: 14)
        ball.cornerRadius = 7
        ball.backgroundColor = NSColor(red: 0.68, green: 0.84, blue: 0.12, alpha: 1).cgColor
        ball.borderColor = NSColor.systemYellow.cgColor
        ball.borderWidth = 1
        view.layer?.addSublayer(ball)
        panel.contentView = view
        panel.orderFrontRegardless()
    }

    func move() { panel.setFrameOrigin(NSPoint(x: x - 8, y: y - 8)) }
    func close() { panel.orderOut(nil); panel.close() }
}

@MainActor
final class OverlayCoordinator: NSObject {
    private let store: PetStore
    private let cache = SpriteCache()
    private var projections: [String: [UUID: PetProjection]] = [:]
    private var balls: [String: BallProjection] = [:]
    private var greetings: [String: GreetingTracker] = [:]
    private var timer: Timer?
    private var timerRate = 0.0
    private var lastTick = ProcessInfo.processInfo.systemUptime
    var onManage: (() -> Void)?

    init(store: PetStore) {
        self.store = store
        super.init()
        store.onChange = { [weak self] in self?.sync() }
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged),
                                               name: NSWorkspace.didWakeNotification, object: NSWorkspace.shared)
        sync()
    }

    @objc private func displaysChanged() { sync() }

    private func screenID(_ screen: NSScreen) -> String { DisplayID.of(screen) }

    private func selectedScreens() -> [NSScreen] {
        switch store.document.displayMode {
        case "main": return NSScreen.main.map { [$0] } ?? []
        case "selected":
            let matching = NSScreen.screens.filter { store.document.selectedDisplays.contains(screenID($0)) }
            return matching.isEmpty ? (NSScreen.main.map { [$0] } ?? []) : matching
        default: return NSScreen.screens
        }
    }

    func sync() {
        let screens = selectedScreens()
        let activeIDs = Set(screens.map(screenID))
        for id in projections.keys where !activeIDs.contains(id) {
            projections.removeValue(forKey: id)?.values.forEach { $0.close() }
            balls.removeValue(forKey: id)?.close()
            greetings.removeValue(forKey: id)
        }
        if store.document.hideAll {
            for ball in balls.values { ball.close() }
            balls.removeAll()
        }
        for screen in screens {
            let id = screenID(screen)
            var shown = projections[id] ?? [:]
            let visible = store.document.hideAll ? [] : store.pets.filter { !$0.hidden }
            let target = Set(visible.map(\.id))
            for old in shown.keys where !target.contains(old) { shown.removeValue(forKey: old)?.close() }
            for (index, pet) in visible.enumerated() where shown[pet.id] == nil {
                let span = max(1, screen.visibleFrame.width - store.document.size)
                let x = screen.visibleFrame.minX + CGFloat(index + 1) * span / CGFloat(visible.count + 1)
                let projection = PetProjection(petID: pet.id, size: store.document.size, x: x)
                projection.view.onFeed = { [weak self] in self?.feed(pet.id) }
                projection.view.onHover = { [weak projection] hovered in
                    projection?.behavior.hover(hovered, at: ProcessInfo.processInfo.systemUptime)
                }
                projection.view.onManage = { [weak self] in self?.onManage?() }
                projection.view.onHide = { [weak self] in
                    self?.store.change { document in
                        if let index = document.pets.firstIndex(where: { $0.id == pet.id }) { document.pets[index].hidden = true }
                    }
                }
                shown[pet.id] = projection
                projection.panel.orderFrontRegardless()
            }
            for projection in shown.values {
                projection.panel.ignoresMouseEvents = store.document.clickThrough
                let size = CGFloat(store.document.size)
                projection.x = DisplayGeometry(visibleFrame: screen.visibleFrame).clamp(x: projection.x, size: size)
                let frame = NSRect(x: projection.x, y: screen.visibleFrame.minY + store.document.floorOffset,
                                   width: size, height: size)
                projection.panel.setFrame(frame, display: true)
            }
            projections[id] = shown
        }
        cache.retain(for: store.pets)
        schedule()
        tick()
    }

    private func schedule() {
        let shouldRun = !store.document.paused && !store.document.hideAll
            && (!projections.values.allSatisfy(\.isEmpty) || !balls.isEmpty)
        guard shouldRun else {
            timer?.invalidate()
            timer = nil
            timerRate = 0
            return
        }
        let moving = !balls.isEmpty || projections.values.contains { group in
            group.values.contains { $0.behavior.phase == .walking || $0.behavior.phase == .chasing }
        }
        let economical = store.document.animationQuality == "low"
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            || ProcessInfo.processInfo.isLowPowerModeEnabled
        let rate = moving ? (economical ? 15.0 : 30.0) : 8.0
        guard timer == nil || timerRate != rate else { return }
        timer?.invalidate()
        timerRate = rate
        let newTimer = Timer(timeInterval: 1.0 / rate, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func tick() {
        let uptime = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, max(0, uptime - lastTick))
        lastTick = uptime
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let sleeping = SleepSchedule(enabled: store.document.bedtime,
                                     startHour: store.document.bedtimeStart,
                                     endHour: store.document.bedtimeEnd).contains(Date())
        for screen in selectedScreens() {
            let id = screenID(screen)
            if let ball = balls[id], !store.document.paused {
                ball.velocity -= 750 * dt
                ball.y += ball.velocity * dt
                let floor = screen.visibleFrame.minY + store.document.floorOffset + 8
                if ball.y <= floor {
                    ball.y = floor
                    ball.bounces += 1
                    ball.velocity = ball.bounces < 4 ? abs(ball.velocity) * 0.42 : 0
                }
                ball.move()
                if uptime - ball.createdAt > 12 {
                    balls.removeValue(forKey: id)?.close()
                }
            }
            let group = projections[id] ?? [:]
            for (petID, projection) in group {
                guard let pet = store.pets.first(where: { $0.id == petID }) else { continue }
                let center = projection.x + projection.panel.frame.width / 2
                let distance = balls[id].map { Double(abs($0.x - center)) }
                projection.behavior.step(at: uptime, bedtime: sleeping, ballDistance: distance,
                                         random: Double.random(in: 0..<1))
                if projection.behavior.phase == .chasing, let ball = balls[id] {
                    projection.behavior.facingLeft = ball.x < center
                }
                let speed: Double = projection.behavior.phase == .chasing ? 145
                    : projection.behavior.phase == .walking ? PetCatalog.walkSpeed(for: pet.species) : 0
                if speed > 0 && !store.document.paused && !reduceMotion {
                    projection.x += (projection.behavior.facingLeft ? -1 : 1) * speed * dt
                    let minX = screen.visibleFrame.minX
                    let maxX = max(minX, screen.visibleFrame.maxX - projection.panel.frame.width)
                    if projection.x <= minX { projection.x = minX; projection.behavior.facingLeft = false }
                    if projection.x >= maxX { projection.x = maxX; projection.behavior.facingLeft = true }
                    projection.panel.setFrameOrigin(NSPoint(x: projection.x, y: projection.panel.frame.minY))
                }
            }
            var tracker = greetings[id] ?? GreetingTracker()
            let list = group.values.sorted { $0.petID.uuidString < $1.petID.uuidString }
            if list.count > 1 {
                for i in 0..<(list.count - 1) {
                    for j in (i + 1)..<list.count {
                        let a = list[i], b = list[j]
                        guard (a.behavior.phase == .walking || a.behavior.phase == .idle),
                              (b.behavior.phase == .walking || b.behavior.phase == .idle),
                              abs(a.x - b.x) < 60,
                              tracker.shouldGreet(a.petID, b.petID, now: uptime) else { continue }
                        a.behavior.greet(at: uptime)
                        b.behavior.greet(at: uptime)
                    }
                }
            }
            greetings[id] = tracker
            if let ball = balls[id], ball.y <= screen.visibleFrame.minY + store.document.floorOffset + 32 {
                let positions = group.values.map { projection in
                    (id: projection.petID,
                     center: Double(projection.x + projection.panel.frame.width / 2),
                     halfWidth: Double(projection.panel.frame.width / 2))
                }
                if let winner = BallCollision.winner(positions, ballX: Double(ball.x)),
                   let projection = group[winner] {
                    projection.behavior.carry(at: uptime)
                    balls.removeValue(forKey: id)?.close()
                }
            }
            for (petID, projection) in group {
                guard let pet = store.pets.first(where: { $0.id == petID }) else { continue }
                let animation: String
                switch projection.behavior.phase {
                case .walking: animation = "walk"
                case .sleeping: animation = "lie"
                case .waving: animation = "swipe"
                case .eating, .idle: animation = "idle"
                case .chasing: animation = "run"
                case .carrying: animation = "with_ball"
                }
                let displayAnimation = reduceMotion && (animation == "walk" || animation == "run") ? "idle" : animation
                if projection.currentAnimation != displayAnimation {
                    projection.currentAnimation = displayAnimation
                    if let url = PetCatalog.animationURL(for: pet, state: displayAnimation) {
                        cache.request(url) { [weak projection] decoded in
                            guard let projection, projection.currentAnimation == displayAnimation else { return }
                            projection.view.setAnimation(decoded, now: ProcessInfo.processInfo.systemUptime)
                        }
                    }
                }
                projection.view.advance(now: uptime)
                projection.view.face(left: pet.species == "dog" ? false : projection.behavior.facingLeft)
            }
        }
        schedule()
    }

    func throwBall() {
        guard !store.document.hideAll else { return }
        let pointer = NSEvent.mouseLocation
        guard let screen = selectedScreens().first(where: { $0.frame.contains(pointer) }) ?? selectedScreens().first else { return }
        let id = screenID(screen)
        balls.removeValue(forKey: id)?.close()
        let x = screen.visibleFrame.midX
        let y = screen.visibleFrame.minY + store.document.floorOffset + 160
        balls[id] = BallProjection(x: x, y: y)
        schedule()
    }

    func feed(_ id: UUID) {
        guard store.feed(id) else { return }
        let uptime = ProcessInfo.processInfo.systemUptime
        for group in projections.values {
            if let projection = group[id] {
                projection.behavior.feed(at: uptime)
                projection.view.showFeedReaction()
            }
        }
    }

    func shutdown() {
        timer?.invalidate()
        timer = nil
        for group in projections.values { group.values.forEach { $0.close() } }
        for ball in balls.values { ball.close() }
        projections.removeAll()
        balls.removeAll()
    }
}
