import ImageIO
import SwiftUI

@MainActor
struct ManagerView: View {
    @ObservedObject var store: PetStore
    @State private var shelterOpen = false
    @State private var chosenSpecies = "dog"
    @State private var chosenVariant = "brown"
    @State private var newName = ""
    @State private var removed: [(pet: PetRecord, index: Int, at: Date)] = []
    @State private var tab = 0
    @State private var screens = NSScreen.screens
    @StateObject private var login = LoginItemController()

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $tab) {
                Text("Pets").tag(0)
                Text("Settings").tag(1)
                Text("Credits").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            Divider()
            if tab == 0 { petsView }
            else if tab == 1 { settingsView }
            else { creditsView }
        }
        .frame(minWidth: 420, minHeight: 430)
    }

    private var petsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Desktop Pets").font(.title2.bold())
                Spacer()
                Button(store.document.hideAll ? "Show Pets" : "Hide All") { store.change { $0.hideAll.toggle() } }
                Button(store.document.paused ? "Resume" : "Pause") { store.change { $0.paused.toggle() } }
            }
            Picker("Animal style", selection: Binding(get: { store.document.petStyle }, set: { value in
                store.change { $0.petStyle = value }
            })) {
                ForEach(PetStyle.allCases, id: \.self) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .disabled(store.loadError != nil)
            .accessibilityIdentifier("animalStylePicker")
            Text("\(PetCatalog.catalog(for: store.document.petStyle).count) species · \(PetCatalog.variantCount(for: store.document.petStyle)) \(store.document.petStyle.title) variants")
                .font(.caption).foregroundStyle(.secondary)
            if store.document.petStyle == .pixel {
                Text("Pixel has one coat per species. Your Realistic coat choices are saved.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Label("\(store.treats.count)/10 treats", systemImage: "heart.fill")
                if store.treats.count < 10 {
                    Text("Next in \(store.treats.secondsUntilNext(at: Date()) / 60 + 1) min")
                        .foregroundStyle(.secondary)
                }
            }
            if let error = store.loadError {
                Text(error).foregroundStyle(.red).textSelection(.enabled)
            }
            if store.pets.isEmpty {
                ContentUnavailableView("It's quiet here", systemImage: "pawprint", description: Text("Visit the shelter to adopt a pet."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.pets) { pet in
                        HStack(spacing: 12) {
                            PetPreview(pet: pet, style: store.document.petStyle)
                                .frame(width: 44, height: 44)
                                .clipped()
                            VStack(alignment: .leading) {
                                TextField("Name", text: nameBinding(pet))
                                Text("\(PetCatalog.displayVariant(for: pet, style: store.document.petStyle).capitalized) \(pet.species.capitalized)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Toggle("Visible", isOn: visibilityBinding(pet)).labelsHidden()
                                .accessibilityLabel("Show \(pet.name)")
                            Button(role: .destructive) { remove(pet) } label: {
                                Image(systemName: "xmark.circle")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove \(pet.name)")
                        }
                        .frame(minHeight: 48)
                    }
                    .onMove { source, destination in
                        store.change { $0.pets.move(fromOffsets: source, toOffset: destination) }
                    }
                }
            }
            if let last = removed.last, Date().timeIntervalSince(last.at) < 5 {
                HStack {
                    Text("Removed \(last.pet.name)")
                    Spacer()
                    Button("Undo") {
                        let item = removed.removeLast()
                        store.restore(item.pet, at: item.index)
                    }
                }
            }
            DisclosureGroup("Visit Shelter", isExpanded: $shelterOpen) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Species", selection: $chosenSpecies) {
                        ForEach(PetCatalog.catalog(for: store.document.petStyle), id: \.species) { entry in
                            Text(entry.species.capitalized).tag(entry.species)
                        }
                    }
                    Picker("Color", selection: $chosenVariant) {
                        ForEach(colors, id: \.self) { color in Text(color.capitalized).tag(color) }
                    }
                    TextField("Name", text: $newName)
                    Button("Adopt Pet") {
                        store.add(species: chosenSpecies, variant: chosenVariant, name: newName)
                        newName = ""
                    }
                    .disabled(store.loadError != nil)
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .onChange(of: chosenSpecies) { _, _ in chosenVariant = colors.first ?? "" }
        .onChange(of: store.document.petStyle) { _, _ in
            if !colors.contains(chosenVariant) { chosenVariant = colors.first ?? "" }
        }
        .onAppear {
            if !colors.contains(chosenVariant) { chosenVariant = colors.first ?? "" }
        }
    }

    private var colors: [String] {
        PetCatalog.catalog(for: store.document.petStyle).first(where: { $0.species == chosenSpecies })?.colors ?? []
    }

    private var settingsView: some View {
        Form {
            Picker("Displays", selection: Binding(get: { store.document.displayMode }, set: { value in store.change { $0.displayMode = value } })) {
                Text("All displays").tag("all")
                Text("Main display").tag("main")
                Text("Selected displays").tag("selected")
            }
            if store.document.displayMode == "selected" {
                ForEach(Array(screens.enumerated()), id: \.offset) { index, screen in
                    Toggle(screen.localizedName + " (\(index + 1))", isOn: displayBinding(screen))
                }
            }
            Picker("Pet size", selection: Binding(get: { store.document.size }, set: { value in store.change { $0.size = value } })) {
                Text("Small").tag(56.0)
                Text("Medium").tag(72.0)
                Text("Large").tag(88.0)
            }
            HStack {
                Text("Floor offset")
                Slider(value: Binding(get: { store.document.floorOffset }, set: { value in store.change { $0.floorOffset = value } }), in: 0...100, step: 5)
                Text("\(Int(store.document.floorOffset)) pt").frame(width: 48)
            }
            Toggle("Click through pets", isOn: Binding(get: { store.document.clickThrough }, set: { value in store.change { $0.clickThrough = value } }))
            Toggle("Bedtime", isOn: Binding(get: { store.document.bedtime }, set: { value in store.change { $0.bedtime = value } }))
            if store.document.bedtime {
                HStack {
                    Picker("From", selection: Binding(get: { store.document.bedtimeStart }, set: { value in store.change { $0.bedtimeStart = value } })) {
                        ForEach(0..<24, id: \.self) { hour in Text(String(format: "%02d:00", hour)).tag(hour) }
                    }
                    Picker("Until", selection: Binding(get: { store.document.bedtimeEnd }, set: { value in store.change { $0.bedtimeEnd = value } })) {
                        ForEach(0..<24, id: \.self) { hour in Text(String(format: "%02d:00", hour)).tag(hour) }
                    }
                }
            }
            Picker("Animation", selection: Binding(get: { store.document.animationQuality }, set: { value in store.change { $0.animationQuality = value } })) {
                Text("Standard").tag("standard")
                Text("Low power").tag("low")
            }
            Picker("Appearance", selection: Binding(get: { store.document.appearance }, set: { value in store.change { $0.appearance = value } })) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            Toggle("Launch at login", isOn: Binding(get: { login.enabled }, set: { login.setEnabled($0) }))
            Text(login.statusText).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear { login.refresh(); screens = NSScreen.screens }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screens = NSScreen.screens
        }
    }

    private var creditsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Artwork and credits").font(.title2.bold())
            Text("In Realistic, four dog color sets are unmodified GIFs from VS Code Pets, credited to NVPH Studio under CC BY-ND 4.0. Horse artwork is by Onfe, adapted by Chris Kent, and used with credit under Onfe’s published permission. All Pixel drawings and the other Realistic drawings were created for this project.")
            Text("Rabbit and forest sprite are generic alternatives to branded characters in the reference extension.")
            Link("VS Code Pets", destination: URL(string: "https://github.com/tonybaloney/vscode-pets")!)
            Link("CC BY-ND 4.0", destination: URL(string: "https://creativecommons.org/licenses/by-nd/4.0/")!)
            Text("This independent macOS app is not affiliated with Pixel Pets or VS Code Pets.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }

    private func nameBinding(_ pet: PetRecord) -> Binding<String> {
        Binding(get: { store.pets.first(where: { $0.id == pet.id })?.name ?? pet.name }, set: { value in
            store.change { document in
                if let index = document.pets.firstIndex(where: { $0.id == pet.id }) {
                    document.pets[index].name = String(value.prefix(32))
                }
            }
        })
    }

    private func visibilityBinding(_ pet: PetRecord) -> Binding<Bool> {
        Binding(get: { !(store.pets.first(where: { $0.id == pet.id })?.hidden ?? false) }, set: { value in
            store.change { document in
                if let index = document.pets.firstIndex(where: { $0.id == pet.id }) { document.pets[index].hidden = !value }
            }
        })
    }

    private func displayBinding(_ screen: NSScreen) -> Binding<Bool> {
        let id = DisplayID.of(screen)
        return Binding(get: { store.document.selectedDisplays.contains(id) }, set: { value in
            store.change { document in
                if value && !document.selectedDisplays.contains(id) { document.selectedDisplays.append(id) }
                if !value { document.selectedDisplays.removeAll { $0 == id } }
            }
        })
    }

    private func remove(_ pet: PetRecord) {
        guard let result = store.remove(pet.id) else { return }
        removed.append((result.0, result.1, Date()))
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            removed.removeAll { Date().timeIntervalSince($0.at) >= 5 }
        }
    }
}

struct PetPreview: NSViewRepresentable {
    let pet: PetRecord
    let style: PetStyle
    func makeNSView(context: Context) -> PetPreviewImageView {
        PetPreviewImageView()
    }
    func updateNSView(_ view: PetPreviewImageView, context: Context) {
        view.show(PetCatalog.animationURL(for: pet, state: "idle", style: style))
    }
}

final class PetPreviewImageView: NSView {
    private var url: URL?
    private var image: CGImage?

    override var isOpaque: Bool { false }
    override var intrinsicContentSize: NSSize { NSSize(width: 44, height: 44) }

    func show(_ url: URL?) {
        guard self.url != url else { return }
        self.url = url
        image = url.flatMap { CGImageSourceCreateWithURL($0 as CFURL, nil) }
            .flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
            .map(Self.croppedToArtwork)
        needsDisplay = true
    }

    private static func croppedToArtwork(_ image: CGImage) -> CGImage {
        let bitmap = NSBitmapImageRep(cgImage: image)
        var left = bitmap.pixelsWide
        var top = bitmap.pixelsHigh
        var right = -1
        var bottom = -1
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.01 {
                left = min(left, x)
                top = min(top, y)
                right = max(right, x)
                bottom = max(bottom, y)
            }
        }
        guard right >= left, bottom >= top else { return image }
        return image.cropping(to: CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)) ?? image
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let image, let context = NSGraphicsContext.current?.cgContext else { return }
        let available = bounds.insetBy(dx: 2, dy: 2)
        let scale = min(available.width / CGFloat(image.width), available.height / CGFloat(image.height))
        let width = floor(CGFloat(image.width) * scale)
        let height = floor(CGFloat(image.height) * scale)
        let rect = CGRect(x: floor(bounds.midX - width / 2), y: floor(bounds.midY - height / 2),
                          width: width, height: height)
        context.interpolationQuality = .none
        context.draw(image, in: rect)
    }
}
