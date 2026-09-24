# Desktop Pets

Desktop Pets is a native, offline macOS menu-bar app for animated pixel companions. It targets macOS 14 or later. Pets use small transparent AppKit panels near the lower usable edge of each selected display; SwiftUI provides the manager. Chrome and browser permissions are not required.

## Run and build

- Open `DesktopPets.xcodeproj` and select the shared **DesktopPets** scheme, or run `./script/build_and_run.sh` from this directory. The script builds, stages, ad hoc signs, and opens `dist/Desktop Pets.app`.
- Run `./script/build_and_run.sh --build-only` to build without opening the app. `--verify` also checks that the app process starts. `--debug`, `--logs`, and `--telemetry` are available for local diagnosis.
- Run `./script/test.sh` for the model and asset tests. Xcode's shared scheme also has a test target.
- Run `./script/build_universal.sh` for the arm64 + x86_64 Release app at `dist/Desktop Pets Universal.app`.
- Codex's **Run** action calls `script/build_and_run.sh`.

The local bundles are ad hoc signed for development. They are **not** Developer ID signed or notarized. Public distribution requires a developer identity, hardened runtime/signing review, notarization, and an installation workflow. The Intel slice compiled, but was not run on Intel hardware. Launch at login uses `SMAppService.mainApp`; the workspace bundle currently reports that it is not eligible for login registration, and the setting shows that status.

## Controls

The paw icon in the menu bar opens **Manage Pets**, **Throw Ball**, **Feed Pet**, **Hide All**, **Pause**, **Click Through**, and **Quit**. Clicking a pet feeds it one shared treat; hovering plays a short reaction, and right-clicking shows Feed, Hide, and Manage Pets. The **Feed Pet** submenu remains available when Click Through disables direct pet interaction. A menu-bar ball starts on the display containing the pointer, at the usable screen's horizontal center.

The manager has a roster with editable names, visibility, removal, drag reorder, and a five-second Undo, plus **Visit Shelter**, Settings, and Credits. The **Realistic / Pixel** switch in Pets changes both roster previews and desktop animals, and its selection persists after relaunch. Realistic contains the existing 35 variants. Pixel has one newly drawn coat per species, with 32 × 32 frames and a small palette. Switching back restores each pet's Realistic coat; names, identity, order, and visibility are preserved. The shelter offers the coats available in the selected style.

Settings include all/main/selected displays, three sizes, floor offset, click-through, bedtime hours, animation quality, appearance, and launch at login. Closing the manager leaves the menu-bar app running. **Pause** freezes simulation and frame updates but leaves pets visible; **Hide All** removes their windows and balls without changing individual visibility settings.

The first clean launch adopts Rex, a brown dog. An intentionally empty roster remains empty after relaunch. State is stored at `~/Library/Application Support/DesktopPets/state.json` using atomic writes; a corrupt or incompatible file is preserved rather than overwritten. The app has no account, analytics, network dependency, screen capture, or Accessibility requirement.

The app icon is original project artwork in `Config/AppIcon.png`; run `python3 script/generate_app_icon.py` to recreate its `.icns` file. Roster previews use the first GIF frame, trim transparent canvas margins in memory, and draw with nearest-neighbor scaling inside equal 44 pt slots.

Realistic artwork uses species-specific anatomy, connected silhouettes, and coherent shading. Twenty variants use original generated artwork packaged as 128 × 128 transparent frames; the 11 horse variants use Onfe's credited animations. The four original dog color sets remain unchanged. Pixel adds 14 original variants with chunky silhouettes, 32 × 32 transparent frames, and at most 15 opaque colors per animal. See [the style comparison](Artwork/Pixel/catalog-preview.png) and [Artwork/README.md](Artwork/README.md) for sources, prompts and regeneration commands.

## Architecture and reference

`PetStore` owns the versioned roster, settings, and shared treat inventory. `PetBehaviorEngine` handles local roaming, reactions, bedtime, and ball competition. `OverlayCoordinator` owns one projection per visible pet per selected display, display-local balls and positions, a shared adaptive timer, and the nonactivating AppKit panels. `SpriteCache` decodes GIFs off the main thread and reuses frames. The panels use clear backgrounds, nearest-neighbor scaling, `canJoinAllSpaces`, `fullScreenAuxiliary`, and the public screen-saver window level discussed in Apple's overlay guidance. macOS 15 and later additionally use `canJoinAllApplications` for Stage Manager related placement. These settings are implemented, but their full-screen and Stage Manager behavior still needs the manual checks in [COMPATIBILITY.md](COMPATIBILITY.md).

The behavior and catalog were checked against [Pixel Pets](https://github.com/nguyenv119/pets) at `da09dab583ef8b8bb83f160eaa81ebef228ee270` and [VS Code Pets](https://github.com/tonybaloney/vscode-pets) at `2c91214beb922288cca1938cddb607abc5f806b7`. The app includes 14 species, 35 Realistic variants and 14 Pixel variants, with six GIF states per variant (294 GIFs). Generic rabbit and forest sprite entries replace the reference's branded Miffy and Totoro entries. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and [Assets/manifest.json](Assets/manifest.json) for provenance. Animation actions fall back to a bundled idle GIF within the selected style when an animation is absent.

## Verification and limits

Fifteen automated tests pass with SwiftPM, including decoding all 294 GIFs, checking frame dimensions and transparent borders, loading legacy saves as Realistic, and preserving pets and coats through persisted style changes. All 210 existing GIF hashes are unchanged. Both rebuilt app bundles contain the verified assets and icon; the universal build has arm64 and x86_64 slices. The Pixel poses were visually inspected at their final resolution. An isolated copy launched successfully, but native UI inspection timed out twice, so live switch interaction and overlay changes remain unverified. Earlier builds passed manager/settings inspection and direct feeding checks; those observations are recorded separately in [COMPATIBILITY.md](COMPATIBILITY.md). See [PERFORMANCE.md](PERFORMANCE.md) for earlier one-display Release samples. Full-screen app/video, multiple Spaces, Stage Manager, sleep/wake, display reconnection, focus preservation, and inter-application click-through still need manual verification on a desktop where those scenarios can be exercised. Interactive panels use compact square hit regions; transparent pixels inside a pet's square may still intercept input, especially while the pet is lying down. Use Click Through when underlying controls are close to a pet. Login/lock screens, protected prompts, exclusive-display modes, and system transition imagery are outside the promised overlay surface.
