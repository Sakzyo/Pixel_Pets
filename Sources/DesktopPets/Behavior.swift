import Foundation
import CoreGraphics

struct DisplayGeometry {
    let visibleFrame: CGRect

    func clamp(x: CGFloat, size: CGFloat) -> CGFloat {
        min(max(x, visibleFrame.minX), max(visibleFrame.minX, visibleFrame.maxX - size))
    }

    func floorY(offset: CGFloat) -> CGFloat { visibleFrame.minY + offset }
}

struct SleepSchedule {
    var enabled = true
    var startHour = 22
    var endHour = 6

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard enabled else { return false }
        let hour = calendar.component(.hour, from: date)
        if startHour < endHour { return hour >= startHour && hour < endHour }
        return hour >= startHour || hour < endHour
    }
}

struct PetBehaviorEngine {
    enum Phase: Equatable {
        case walking, idle, sleeping, waving, eating, chasing, carrying
    }

    var phase: Phase = .walking
    var facingLeft = false
    private(set) var hovered = false
    private var until: TimeInterval = 0

    init(now: TimeInterval = 0) { until = now + 2 }

    mutating func hover(_ inside: Bool, at now: TimeInterval) {
        guard hovered != inside else { return }
        hovered = inside
        if inside && phase != .eating && phase != .carrying {
            phase = .waving
            until = now + 1
        }
    }

    mutating func feed(at now: TimeInterval) {
        phase = .eating
        until = now + 1.5
    }

    mutating func carry(at now: TimeInterval) {
        phase = .carrying
        until = now + 1.5
    }

    mutating func greet(at now: TimeInterval) {
        guard phase == .walking || phase == .idle else { return }
        phase = .waving
        until = now + 1
    }

    mutating func step(at now: TimeInterval, bedtime: Bool, ballDistance: Double?, random: Double) {
        if phase == .eating || phase == .carrying {
            if now < until { return }
            phase = bedtime ? .sleeping : .idle
            until = now + 1
        }
        if hovered {
            if phase != .eating && phase != .carrying { phase = .waving }
            return
        }
        if phase == .waving && now < until { return }
        if bedtime {
            phase = .sleeping
            return
        }
        if let ballDistance, ballDistance < 600 {
            phase = .chasing
            return
        }
        if phase == .sleeping && now < until { return }
        if phase == .chasing || phase == .sleeping || phase == .waving {
            phase = .idle
            until = now + 1.5
            return
        }
        guard now >= until else { return }
        switch phase {
        case .idle:
            if random < 0.4 {
                phase = .walking
                facingLeft = true
                until = now + 3 + random * 5
            } else if random < 0.8 {
                phase = .walking
                facingLeft = false
                until = now + 3 + random * 5
            } else {
                phase = .sleeping
                until = now + 4 + random * 4
            }
        case .walking:
            if random < 0.6 {
                phase = .idle
                until = now + 2 + random * 2
            } else {
                facingLeft.toggle()
                until = now + 3 + random * 5
            }
        default:
            phase = .idle
            until = now + 2
        }
    }
}

struct GreetingTracker {
    static let cooldown: TimeInterval = 30
    private var last: [String: TimeInterval] = [:]

    mutating func shouldGreet(_ a: UUID, _ b: UUID, now: TimeInterval) -> Bool {
        let key = [a.uuidString, b.uuidString].sorted().joined(separator: ":")
        if let previous = last[key], now - previous < Self.cooldown { return false }
        last[key] = now
        return true
    }
}

struct BallCollision {
    static func winner(_ positions: [(id: UUID, center: Double, halfWidth: Double)], ballX: Double) -> UUID? {
        positions
            .filter { abs($0.center - ballX) < $0.halfWidth + 8 }
            .min { a, b in
                let da = abs(a.center - ballX)
                let db = abs(b.center - ballX)
                return da == db ? a.id.uuidString < b.id.uuidString : da < db
            }?.id
    }
}
