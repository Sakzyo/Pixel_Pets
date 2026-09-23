import AppKit
import Combine
import Foundation

struct PetRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var species: String
    var variant: String
    var hidden = false
}

struct TreatInventory: Codable, Equatable {
    static let capacity = 10
    static let interval: TimeInterval = 600
    var count = capacity
    var updatedAt = Date()

    mutating func reconcile(at now: Date) {
        count = min(max(count, 0), Self.capacity)
        guard count < Self.capacity else { updatedAt = now; return }
        let elapsed = now.timeIntervalSince(updatedAt)
        guard elapsed >= Self.interval else { return }
        let gained = min(Self.capacity - count, Int(elapsed / Self.interval))
        count += gained
        updatedAt = count == Self.capacity ? now : updatedAt.addingTimeInterval(Double(gained) * Self.interval)
    }

    mutating func consume(at now: Date) -> Bool {
        reconcile(at: now)
        guard count > 0 else { return false }
        if count == Self.capacity { updatedAt = now }
        count -= 1
        return true
    }

    func secondsUntilNext(at now: Date) -> Int {
        guard count < Self.capacity else { return 0 }
        return max(0, Int(ceil(Self.interval - max(0, now.timeIntervalSince(updatedAt)))))
    }
}

struct AppDocument: Codable {
    var version = 1
    var pets: [PetRecord]
    var treats = TreatInventory()
    var hideAll = false
    var paused = false
    var clickThrough = false
    var size = 72.0
    var floorOffset = 0.0
    var bedtime = true
    var bedtimeStart = 22
    var bedtimeEnd = 6
    var displayMode = "all"
    var selectedDisplays: [String] = []
    var appearance = "system"
    var animationQuality = "standard"

    init(pets: [PetRecord]) { self.pets = pets }

    private enum CodingKeys: String, CodingKey {
        case version, pets, treats, hideAll, paused, clickThrough, size, floorOffset,
             bedtime, bedtimeStart, bedtimeEnd, displayMode, selectedDisplays,
             appearance, animationQuality
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        pets = try c.decode([PetRecord].self, forKey: .pets)
        treats = try c.decodeIfPresent(TreatInventory.self, forKey: .treats) ?? TreatInventory()
        hideAll = try c.decodeIfPresent(Bool.self, forKey: .hideAll) ?? false
        paused = try c.decodeIfPresent(Bool.self, forKey: .paused) ?? false
        clickThrough = try c.decodeIfPresent(Bool.self, forKey: .clickThrough) ?? false
        size = try c.decodeIfPresent(Double.self, forKey: .size) ?? 72
        floorOffset = try c.decodeIfPresent(Double.self, forKey: .floorOffset) ?? 0
        bedtime = try c.decodeIfPresent(Bool.self, forKey: .bedtime) ?? true
        bedtimeStart = try c.decodeIfPresent(Int.self, forKey: .bedtimeStart) ?? 22
        bedtimeEnd = try c.decodeIfPresent(Int.self, forKey: .bedtimeEnd) ?? 6
        displayMode = try c.decodeIfPresent(String.self, forKey: .displayMode) ?? "all"
        selectedDisplays = try c.decodeIfPresent([String].self, forKey: .selectedDisplays) ?? []
        appearance = try c.decodeIfPresent(String.self, forKey: .appearance) ?? "system"
        animationQuality = try c.decodeIfPresent(String.self, forKey: .animationQuality) ?? "standard"
        guard size >= 40, size <= 120, floorOffset >= 0, floorOffset <= 200,
              (0...23).contains(bedtimeStart), (0...23).contains(bedtimeEnd) else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }
}

enum DisplayID {
    static func of(_ screen: NSScreen) -> String {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.stringValue ?? String(describing: screen.frame)
    }
}

enum PetCatalog {
    // Horses and four dog colors are credited upstream assets; the rest are original artwork.
    // Miffy and Totoro are replaced by a generic rabbit and forest sprite.
    static let variants: [(species: String, colors: [String])] = [
        ("chicken", ["brown", "white"]),
        ("cockatiel", ["brown", "gray"]),
        ("crab", ["red"]),
        ("dog", ["akita", "black", "brown", "red", "white"]),
        ("fox", ["red", "white"]),
        ("horse", ["black", "brown", "white", "magical", "warrior", "paint_beige", "paint_black", "paint_brown", "socks_beige", "socks_black", "socks_brown"]),
        ("monkey", ["gray"]),
        ("panda", ["black", "brown"]),
        ("rat", ["brown", "gray", "white"]),
        ("snail", ["brown"]),
        ("snake", ["green"]),
        ("turtle", ["green", "orange"]),
        ("rabbit", ["white"]),
        ("forest_sprite", ["blue"])
    ]

    static var variantCount: Int { variants.reduce(0) { $0 + $1.colors.count } }

    static func walkSpeed(for species: String) -> Double {
        switch species {
        case "snail": return 18
        case "turtle", "crab": return 38
        case "horse": return 70
        case "rabbit", "fox": return 65
        default: return 55
        }
    }

    static func has(_ pet: PetRecord) -> Bool {
        variants.contains { $0.species == pet.species && $0.colors.contains(pet.variant) }
    }

    static func animationURL(for pet: PetRecord, state: String) -> URL? {
        let name = "\(pet.variant)_\(state)_8fps.gif"
        let url = Bundle.main.resourceURL?.appendingPathComponent("Assets/\(pet.species)/\(name)")
        if let url, FileManager.default.fileExists(atPath: url.path) { return url }
        return Bundle.main.resourceURL?.appendingPathComponent("Assets/\(pet.species)/\(pet.variant)_idle_8fps.gif")
    }
}

@MainActor
final class PetStore: ObservableObject {
    @Published private(set) var document: AppDocument
    @Published private(set) var loadError: String?
    var onChange: (() -> Void)?
    private let url: URL

    init(url: URL? = nil) {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DesktopPets", isDirectory: true)
        self.url = url ?? folder.appendingPathComponent("state.json")
        if FileManager.default.fileExists(atPath: self.url.path) {
            do {
                let data = try Data(contentsOf: self.url)
                let decoded = try JSONDecoder().decode(AppDocument.self, from: data)
                guard decoded.version == 1, decoded.pets.allSatisfy(PetCatalog.has) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                document = decoded
                document.treats.reconcile(at: Date())
            } catch {
                loadError = "Saved pets could not be read: \(error.localizedDescription). The file was left untouched."
                document = AppDocument(pets: [])
            }
        } else {
            document = AppDocument(pets: [PetRecord(id: UUID(), name: "Rex", species: "dog", variant: "brown")])
            save()
        }
    }

    var pets: [PetRecord] { document.pets }
    var treats: TreatInventory { document.treats }

    func change(_ update: (inout AppDocument) -> Void) {
        guard loadError == nil else { return }
        update(&document)
        save()
        onChange?()
    }

    func add(species: String, variant: String, name: String) {
        let pet = PetRecord(id: UUID(), name: name.isEmpty ? species.capitalized : String(name.prefix(32)), species: species, variant: variant)
        guard PetCatalog.has(pet) else { return }
        change { $0.pets.append(pet) }
    }

    func remove(_ id: UUID) -> (PetRecord, Int)? {
        guard let index = document.pets.firstIndex(where: { $0.id == id }) else { return nil }
        let pet = document.pets[index]
        change { $0.pets.remove(at: index) }
        return (pet, index)
    }

    func restore(_ pet: PetRecord, at index: Int) {
        change { $0.pets.insert(pet, at: min(index, $0.pets.count)) }
    }

    func feed(_ id: UUID) -> Bool {
        guard document.pets.contains(where: { $0.id == id && !$0.hidden }), !document.hideAll else { return false }
        var success = false
        change { success = $0.treats.consume(at: Date()) }
        return success
    }

    func refreshTreats() { change { $0.treats.reconcile(at: Date()) } }

    private func save() {
        guard loadError == nil else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(document)
            try data.write(to: url, options: .atomic)
        } catch {
            loadError = "Could not save pets: \(error.localizedDescription)"
        }
    }
}
