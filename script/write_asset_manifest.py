"""Record the precise source and checksum for every bundled GIF."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Assets"
UPSTREAM_COMMIT = "2c91214beb922288cca1938cddb607abc5f806b7"
REFERENCE_COMMIT = "da09dab583ef8b8bb83f160eaa81ebef228ee270"
SHEETS = json.loads((ROOT / "Artwork/sheets.json").read_text())
ORIGINAL_SOURCES = {
    (sheet["species"], variant): f"Artwork/{sheet['file']}"
    for sheet in SHEETS for variant in sheet["variants"]
}

items = []
for path in sorted(ASSETS.glob("*/*.gif")):
    relative = path.relative_to(ROOT).as_posix()
    upstream_dog = path.parent.name == "dog" and not path.name.startswith("akita_")
    if upstream_dog:
        info = {
            "source": f"https://github.com/tonybaloney/vscode-pets/blob/{UPSTREAM_COMMIT}/media/dog/{path.name}",
            "creator": "NVPH Studio (credited for dog artwork in upstream README)",
            "license": "CC BY-ND 4.0 (upstream media/dog/license.txt)",
            "modifications": "None; original GIF bytes copied verbatim",
        }
    elif path.parent.name == "horse":
        source_name = path.name.replace("_lie_", "_stand_")
        info = {
            "source": f"https://github.com/tonybaloney/vscode-pets/blob/{UPSTREAM_COMMIT}/media/horse/{source_name}",
            "creator": "Onfe; GIF adaptations by Chris Kent for VS Code Pets",
            "license": "Onfe custom permission: personal/commercial use and edits with credit; Assets/horse/license.txt",
            "modifications": "GIF bytes unchanged; stand animation also used for the resting state",
        }
    else:
        variant = path.name.rsplit("_", 2)[0]
        # with_ball is the one action name containing an underscore.
        if variant.endswith("_with"):
            variant = variant.removesuffix("_with")
        info = {
            "source": ORIGINAL_SOURCES[(path.parent.name, variant)],
            "creator": "Desktop Pets project, created with OpenAI image generation",
            "license": "Project-original artwork; no external image incorporated",
            "modifications": "Frame extraction, uniform scale and baseline, shared palette and transparent GIF encoding",
        }
    items.append({"path": relative, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), **info})

manifest = {
    "referenceExtension": f"https://github.com/nguyenv119/pets/tree/{REFERENCE_COMMIT}",
    "upstreamSprites": f"https://github.com/tonybaloney/vscode-pets/tree/{UPSTREAM_COMMIT}",
    "catalogVariants": len({(p.parent.name, p.name.split("_idle_8fps.gif")[0]) for p in ASSETS.glob("*/*_idle_8fps.gif")}),
    "files": items,
}
(ASSETS / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(f"Recorded {len(items)} GIFs")
