# Desktop Pets 1.0.0

Native, offline desktop companions for macOS 14 and later.

## Included

- 16 species, including cats and deer.
- 40 Realistic variants and 35 Pixel variants, with 450 bundled animations.
- A saved Realistic / Pixel switch, with at least two Pixel colors per species.
- Editable pet names, shelter adoption, visibility, roster ordering, and removal with Undo.
- Treats, feeding reactions, bedtime, ball play, pause, and click-through controls.
- Display selection, pet sizes, floor offset, and appearance settings.
- Original app icon and bundled artwork credits.

## Download and install

Download `Desktop-Pets-1.0.0-universal.dmg`, open it, and drag **Desktop Pets.app**
to **Applications**. Eject the disk image and launch the installed app. Choose
**Manage Pets** from the paw icon in the menu bar.

The DMG includes both Apple silicon and Intel binaries. A SHA-256 checksum file
is supplied beside it. Source, artwork, and exact generation prompts are in the
repository.

## Signing and verification limits

**This release is ad hoc signed and is not notarized.** No Developer ID signing
certificate was available for this build. macOS Gatekeeper may block the app
after download; this is not a Developer ID signed distribution.

The 16 automated tests pass, covering persistence, behavior, catalog completeness,
and decoding all 450 GIFs. The DMG passes integrity and checksum verification;
the app copied from it passes signature and asset checks and launches successfully.
Intel was compiled but has not been run on Intel
hardware. Native UI inspection timed out during artwork verification; live shelter
and style-switch interaction remain unverified. Full-screen, Spaces, Stage
Manager, multiple displays, and launch-at-login acceptance checks remain listed
in [COMPATIBILITY.md](https://github.com/Sakzyo/Pixel_Pets/blob/v1.0.0/COMPATIBILITY.md).

## Rebuild

Run `./script/test.sh`, then `./script/package_dmg.sh`. The packaging script builds
the universal Release app, creates and verifies the compressed DMG, and writes
its checksum under `dist/`. Both build paths read their version from
`Config/Info.plist`.
