# Compatibility and acceptance matrix

Test host: MacBook Air (Apple M4, 32 GB), macOS 26.5.2, Xcode 26.6, one built-in Retina display. **Passed** means the stated check was observed on this host. **Untested** is not a claim of failure.

| Scenario | Result | Evidence or remaining check |
| --- | --- | --- |
| SwiftPM debug build and twelve unit tests | Passed | `./script/test.sh`: 12 passed, 0 failed, after the animal artwork update. |
| Updated sprite assets and bundle resources | Passed | All 210 GIFs decode; generated frames are 128 px with transparent borders. Both bundles match the manifest hashes and include the app icon. Extracted artwork was visually inspected. |
| Updated artwork in native manager and overlay | UI inspection blocked | Isolated universal app launched and loaded its test roster; the native UI tool timed out twice. Earlier manager/overlay observations below predate this artwork update. |
| Xcode shared scheme build and tests | Passed | Debug build; Xcode test result: 11 passed, 0 failed. |
| Universal Release compilation | Passed | `xcodebuild` produced arm64 and x86_64 slices; Intel runtime untested. |
| App bundle launch and visible pet | Passed | Ad hoc signed bundle launched; a transparent 72 pt pet panel displayed Rex. |
| Manager, shelter, and settings window | Passed | Native manager opened; roster, shelter species/color/name, and settings were visible via UI inspection. |
| Direct click feeds one treat | Passed | Click on a stationary pet changed an isolated Release-state inventory from 10 to 9; the final build visibly showed its affection cue. |
| First launch, empty roster, persistence, reorder, Undo, corrupt-file preservation | Passed in automated tests | Model tests cover durable data and identifiers; drag and five-second UI timing still need manual verification. |
| Treat regeneration, bedtime, greeting cooldown, collision ownership, negative-origin geometry | Passed in automated tests | Pure model tests use fixed times and inputs. |
| Ordinary app switching and keyboard focus after pet interaction | Untested | Confirm previously focused editor continues receiving typing. |
| Click-through to an underlying app: clicks, scroll, selection, drag, double-click | Untested | `ignoresMouseEvents` is implemented for full Click Through mode; verify across applications. In interactive mode, transparent pixels inside the pet's square can still intercept input. |
| Rapid pointer movement, hover, overlapping pets | Untested | Verify reactions and hit regions in a live session. |
| Multiple desktop Spaces and repeated Space changes | Untested | Verify visibility and absence of duplicate windows. |
| Safari/editor full screen and full-screen video | Untested | Verify without exiting full screen or stealing focus. |
| Stage Manager | Untested | Check on macOS 15+ with Stage Manager enabled. |
| Display reconnection, rotated/negative-origin layouts, two-display behavior | Untested | Only one built-in display was connected. |
| Sleep/wake and time-zone changes | Untested | Wake handler and local-time schedule exist; live transition not exercised. |
| Close manager, Hide All, Pause, Quit lifecycle | Untested | Source implements distinct behavior; verify with UI and process inspection. |
| Menu-bar feeding in click-through mode | Untested | Feed submenu is present in source and compiles; live menu action not exercised. |
| Launch at login | Untested | Workspace bundle reports `SMAppService.mainApp.status == .notFound`; installed and properly signed app needs a separate check. |
| Intel execution | Untested | x86_64 slice compiled but no Intel Mac was available. |

The supported design boundary is normal user-session windows and supported full-screen Spaces. macOS controls login and lock screens, protected prompts, exclusive-display modes, and system transition imagery; the app does not attempt to cover them.
