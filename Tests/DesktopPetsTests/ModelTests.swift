import AppKit
import CryptoKit
import Foundation
import XCTest
@testable import DesktopPets

final class ModelTests: XCTestCase {
    func testTreatRechargeAndCapacity() {
        let start = Date(timeIntervalSince1970: 1_000)
        var inventory = TreatInventory(count: 4, updatedAt: start)
        inventory.reconcile(at: start.addingTimeInterval(1_250))
        XCTAssertEqual(inventory.count, 6)
        XCTAssertEqual(inventory.updatedAt, start.addingTimeInterval(1_200))
        inventory.reconcile(at: start.addingTimeInterval(20_000))
        XCTAssertEqual(inventory.count, 10)
        XCTAssertEqual(inventory.updatedAt, start.addingTimeInterval(20_000))
        XCTAssertTrue(inventory.consume(at: start.addingTimeInterval(20_000)))
        XCTAssertEqual(inventory.count, 9)
        XCTAssertEqual(inventory.secondsUntilNext(at: start.addingTimeInterval(20_100)), 500)
    }

    func testTreatClockRollbackAndRepeatedConsumption() {
        let start = Date(timeIntervalSince1970: 10_000)
        var inventory = TreatInventory(count: 2, updatedAt: start)
        inventory.reconcile(at: start.addingTimeInterval(-3_600))
        XCTAssertEqual(inventory.count, 2)
        XCTAssertTrue(inventory.consume(at: start))
        XCTAssertTrue(inventory.consume(at: start))
        XCTAssertFalse(inventory.consume(at: start))
        XCTAssertEqual(inventory.count, 0)
    }

    func testTreatCountIsClampedAfterLoading() {
        let now = Date(timeIntervalSince1970: 1_000)
        var tooMany = TreatInventory(count: 99, updatedAt: now)
        tooMany.reconcile(at: now)
        XCTAssertEqual(tooMany.count, 10)
        var negative = TreatInventory(count: -3, updatedAt: now)
        negative.reconcile(at: now)
        XCTAssertEqual(negative.count, 0)
    }

    func testSleepScheduleAcrossMidnight() {
        let calendar = Calendar(identifier: .gregorian)
        let dates = [21, 22, 0, 5, 6].map { hour in
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: hour))!
        }
        let schedule = SleepSchedule()
        XCTAssertEqual(dates.map { schedule.contains($0, calendar: calendar) }, [false, true, true, true, false])
        XCTAssertFalse(SleepSchedule(enabled: false).contains(dates[2], calendar: calendar))
        XCTAssertTrue(SleepSchedule(startHour: 9, endHour: 17).contains(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 12))!, calendar: calendar))
    }

    func testBehaviorInterruptionsAndResume() {
        var pet = PetBehaviorEngine(now: 0)
        pet.hover(true, at: 1)
        XCTAssertEqual(pet.phase, .waving)
        pet.feed(at: 1.1)
        pet.step(at: 1.2, bedtime: true, ballDistance: 20, random: 0.5)
        XCTAssertEqual(pet.phase, .eating)
        pet.hover(false, at: 1.3)
        pet.step(at: 3, bedtime: true, ballDistance: 20, random: 0.5)
        XCTAssertEqual(pet.phase, .sleeping)
        pet.step(at: 4, bedtime: false, ballDistance: 20, random: 0.5)
        XCTAssertEqual(pet.phase, .chasing)
        pet.carry(at: 4)
        pet.step(at: 4.5, bedtime: false, ballDistance: nil, random: 0.5)
        XCTAssertEqual(pet.phase, .carrying)
        pet.step(at: 6, bedtime: false, ballDistance: nil, random: 0.5)
        XCTAssertEqual(pet.phase, .idle)
    }

    func testGreetingPairCooldownIsOrderIndependent() {
        let a = UUID(), b = UUID()
        var tracker = GreetingTracker()
        XCTAssertTrue(tracker.shouldGreet(a, b, now: 100))
        XCTAssertFalse(tracker.shouldGreet(b, a, now: 129))
        XCTAssertTrue(tracker.shouldGreet(b, a, now: 130))
    }

    func testCollisionChoosesClosestContactNotRosterOrder() {
        let left = UUID(), right = UUID()
        let positions: [(id: UUID, center: Double, halfWidth: Double)] = [
            (left, 80, 12), (right, 98, 12)
        ]
        XCTAssertEqual(BallCollision.winner(positions, ballX: 95), right)
        XCTAssertEqual(BallCollision.winner(positions.reversed(), ballX: 95), right)
        XCTAssertNil(BallCollision.winner(positions, ballX: 200))
    }

    func testDisplayClampWithNegativeOrigin() {
        let geometry = DisplayGeometry(visibleFrame: CGRect(x: -1920, y: 25, width: 1920, height: 1000))
        XCTAssertEqual(geometry.clamp(x: -2000, size: 72), -1920)
        XCTAssertEqual(geometry.clamp(x: 20, size: 72), -72)
        XCTAssertEqual(geometry.floorY(offset: 40), 65)
    }

    @MainActor
    func testRosterPersistenceReorderUndoAndEmptyIntent() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = PetStore(url: url)
        XCTAssertEqual(store.pets.map(\.name), ["Rex"])
        store.add(species: "rabbit", variant: "white", name: "Pip")
        store.add(species: "dog", variant: "black", name: "Jet")
        store.change { $0.pets.swapAt(0, 2) }
        XCTAssertEqual(store.pets.map(\.name), ["Jet", "Pip", "Rex"])
        let first = store.remove(store.pets[0].id)!
        let second = store.remove(store.pets[0].id)!
        store.restore(second.0, at: second.1)
        store.restore(first.0, at: first.1)
        XCTAssertEqual(store.pets.map(\.name), ["Jet", "Pip", "Rex"])
        store.change { $0.hideAll = true; $0.pets[1].hidden = true }
        store.change { $0.hideAll = false }
        XCTAssertTrue(store.pets[1].hidden)
        for pet in store.pets { _ = store.remove(pet.id) }
        XCTAssertTrue(PetStore(url: url).pets.isEmpty)
    }

    @MainActor
    func testCorruptFileIsPreserved() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let corrupt = Data("{broken".utf8)
        try corrupt.write(to: url)
        let store = PetStore(url: url)
        XCTAssertNotNil(store.loadError)
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
        store.add(species: "dog", variant: "brown", name: "Nope")
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
    }

    func testAssetManifestAndCatalog() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let assets = root.appendingPathComponent("Assets")
        let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: assets.appendingPathComponent("manifest.json"))) as! [String: Any]
        let files = manifest["files"] as! [[String: Any]]
        let total = PetStyle.allCases.reduce(0) { $0 + PetCatalog.variantCount(for: $1) }
        XCTAssertEqual(manifest["catalogVariants"] as? Int, total)
        XCTAssertEqual(files.count, total * 6)
        for entry in files {
            let file = root.appendingPathComponent(entry["path"] as! String)
            let digest = SHA256.hash(data: try Data(contentsOf: file)).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(digest, entry["sha256"] as? String, file.path)
        }
        for style in PetStyle.allCases {
            XCTAssertEqual((manifest["styleVariants"] as? [String: Int])?[style.rawValue], PetCatalog.variantCount(for: style))
            for entry in PetCatalog.catalog(for: style) {
                for color in entry.colors {
                    let pet = PetRecord(id: UUID(), name: "Test", species: entry.species, variant: color)
                    for state in ["idle", "walk", "run", "swipe", "lie", "with_ball"] {
                        let path = PetCatalog.animationPath(for: pet, state: state, style: style)
                        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path), path)
                    }
                }
            }
        }
    }

    func testSpriteDecodingResolutionAndTransparentMargins() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf:
            root.appendingPathComponent("Assets/manifest.json"))) as! [String: Any]
        for entry in manifest["files"] as! [[String: Any]] {
            let path = entry["path"] as! String
            let animation = try XCTUnwrap(SpriteAnimation.load(root.appendingPathComponent(path)), path)
            XCTAssertEqual(animation.frames.count, animation.durations.count, path)
            let generated = (entry["source"] as! String).hasPrefix("Artwork/")
            let pixel = entry["style"] as? String == "pixel"
            if generated && ["idle", "walk", "run"].contains(where: { path.hasSuffix("_\($0)_8fps.gif") }) {
                XCTAssertGreaterThan(animation.frames.count, 1, path)
            }
            for frame in animation.frames {
                XCTAssertGreaterThanOrEqual(frame.width, pixel ? 32 : 64, path)
                XCTAssertGreaterThanOrEqual(frame.height, pixel ? 32 : 64, path)
                guard generated else { continue }
                let size = pixel ? 32 : 128
                XCTAssertEqual(frame.width, size, path)
                XCTAssertEqual(frame.height, size, path)
                let bitmap = NSBitmapImageRep(cgImage: frame)
                for offset in 0..<size {
                    for (x, y) in [(0, offset), (size-1, offset), (offset, 0), (offset, size-1)] {
                        XCTAssertEqual(bitmap.colorAt(x: x, y: y)?.alphaComponent, 0, path)
                    }
                }
            }
        }
    }

    func testExistingDocumentsDefaultToRealistic() throws {
        let legacy = Data(#"{"version":1,"pets":[{"id":"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE","name":"Snow","species":"fox","variant":"white","hidden":true}],"paused":true}"#.utf8)
        let document = try JSONDecoder().decode(AppDocument.self, from: legacy)
        XCTAssertEqual(document.petStyle, .realistic)
        XCTAssertEqual(document.pets.first?.variant, "white")
        XCTAssertEqual(document.pets.first?.hidden, true)
        XCTAssertTrue(document.paused)
    }

    @MainActor
    func testStylePersistsWithoutChangingPetsOrCoats() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = PetStore(url: url)
        store.add(species: "fox", variant: "white", name: "Snow")
        store.add(species: "horse", variant: "magical", name: "Star")
        store.change { $0.pets[1].hidden = true; $0.paused = true }
        let originalPets = store.pets
        store.change { $0.petStyle = .pixel }
        let restored = PetStore(url: url)
        XCTAssertEqual(restored.document.petStyle, .pixel)
        XCTAssertTrue(restored.document.paused)
        XCTAssertEqual(restored.pets, originalPets)
        XCTAssertEqual(PetCatalog.displayVariant(for: restored.pets[1], style: .pixel), "white")
        restored.change { $0.petStyle = .realistic }
        XCTAssertEqual(PetStore(url: url).pets, originalPets)
        XCTAssertEqual(PetCatalog.displayVariant(for: restored.pets[1], style: .realistic), "white")
    }

    func testAllExistingPetsHaveDistinctPixelAssetsForEveryAction() {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        XCTAssertEqual(Set(PetCatalog.variants.map(\.species)), Set(PetCatalog.pixelVariants.map(\.species)))
        for entry in PetCatalog.variants {
            for variant in entry.colors {
                let pet = PetRecord(id: UUID(), name: "Test", species: entry.species, variant: variant)
                for state in ["idle", "walk", "run", "swipe", "lie", "with_ball"] {
                    let realistic = PetCatalog.animationPath(for: pet, state: state, style: .realistic)
                    let pixel = PetCatalog.animationPath(for: pet, state: state, style: .pixel)
                    XCTAssertNotEqual(realistic, pixel)
                    XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(pixel).path), pixel)
                }
            }
        }
    }

    @MainActor
    func testExpandedPixelColorsAndNewSpeciesPersistAcrossStyles() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = PetStore(url: url)
        store.change { $0.pets = []; $0.petStyle = .pixel }
        for entry in PetCatalog.pixelVariants {
            XCTAssertGreaterThanOrEqual(entry.colors.count, 2, entry.species)
            for color in entry.colors {
                store.add(species: entry.species, variant: color, name: "\(color) \(entry.species)")
            }
        }
        XCTAssertEqual(store.pets.count, PetCatalog.variantCount(for: .pixel))
        let originalPets = store.pets
        store.change { $0.petStyle = .realistic }
        let restored = PetStore(url: url)
        XCTAssertNil(restored.loadError)
        XCTAssertEqual(restored.pets, originalPets)
        let crab = try XCTUnwrap(restored.pets.first { $0.species == "crab" && $0.variant == "blue" })
        XCTAssertEqual(PetCatalog.displayVariant(for: crab, style: .realistic), "red")
        restored.change { $0.petStyle = .pixel }
        XCTAssertEqual(PetCatalog.displayVariant(for: crab, style: .pixel), "blue")
        XCTAssertEqual(PetStore(url: url).pets, originalPets)
        for style in PetStyle.allCases {
            for species in ["cat", "deer"] {
                XCTAssertNotNil(PetCatalog.catalog(for: style).first { $0.species == species })
            }
        }
        XCTAssertFalse(PetCatalog.has(PetRecord(id: UUID(), name: "Invalid", species: "cat", variant: "invalid")))
    }
}
