# Release performance notes

Measured on 2026-09-23 with an Apple M4 MacBook Air (10 CPU cores, 32 GB RAM), macOS 26.5.2, one built-in 2560 × 1664 Retina display. The final Xcode Release app contained arm64 and x86_64 slices and ran on arm64. Each row used an isolated JSON roster with bedtime disabled. Five `ps` readings about one second apart were taken after roughly four seconds of launch warm-up. CPU is `ps %cpu`; resident memory is `ps rss`, converted from KiB. These are short observations, not steady-state or battery-life promises.

| Visible pets | DesktopPets CPU range | DesktopPets RSS range | WindowServer CPU range | WindowServer RSS range |
| ---: | ---: | ---: | ---: | ---: |
| 0 (app stopped) | — | — | 41.1–47.0% | 290.8–290.9 MiB |
| 1 | 6.1–7.0% | 48.0–48.1 MiB | 41.4–44.0% | 290.8–290.9 MiB |
| 5 | 7.3–8.9% | 46.3–46.4 MiB | 40.8–43.5% | 290.9 MiB |
| 15 | 10.2–13.0% | 53.2–53.4 MiB | 41.6–43.7% | 291.2 MiB |

WindowServer is shared by the entire desktop. Its baseline ranged from 41–47% on this host, so these numbers cannot attribute a CPU difference to Desktop Pets alone. The 1-pet range includes post-launch work. The rosters use different species and animations, so their memory values are not a controlled per-pet scaling curve. No external monitor was connected, so a two-display sample was unavailable. Instruments energy traces, power draw, thermals, and longer steady-state runs were not measured.

The app uses one timer across projections, targets 30 Hz for motion (15 Hz in low-power/Reduce Motion mode), uses 8 Hz while resting, pauses when hidden or paused, and decodes GIFs off the main thread. The figures above are the measured evidence for this machine, not a general efficiency guarantee.
