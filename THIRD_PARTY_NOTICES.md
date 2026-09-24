# Third-party artwork

Four Realistic dog color sets (`brown`, `black`, `red`, `white`) are copied byte-for-byte
from [VS Code Pets](https://github.com/tonybaloney/vscode-pets), commit
`2c91214beb922288cca1938cddb607abc5f806b7`. That project's README credits
[NVPH Studio](https://nvph-studio.itch.io/dog-animation-4-different-dogs) for dog
artwork. Its `media/dog/license.txt` states **Creative Commons Attribution–NoDerivatives
4.0 International**. The notice is reproduced in `Assets/dog/license.txt`.
The [license terms](https://creativecommons.org/licenses/by-nd/4.0/) apply to these
GIF files separately from any code license. The GIF bytes were not changed,
and the app does not mirror these dog sprites at runtime.

The Realistic horse GIFs are artwork by [Onfe](https://onfe.itch.io/horse-sprite-with-rider-asset-pack),
adapted by [Chris Kent](https://github.com/thechriskent) for VS Code Pets at the
same commit. Onfe permits personal/commercial project use and edits with credit,
and explicitly allows sharing GIFs in project repositories. These GIF bytes are
unchanged; the standing animation is also used for the horse's resting state.
The permission and source details are recorded in `Assets/horse/license.txt`.

The other 120 Realistic GIFs and all 84 Pixel GIFs were created for this project
using OpenAI's built-in image generation tool. The 13 Realistic RGBA sheets are
in `Artwork/`; the 14 new Pixel sheets are in `Artwork/Pixel/`, including original
Pixel dog and horse artwork. Each folder records exact prompts, variant order,
and reviewed frame bounds in `sheets.json`. `script/generate_original_sprites.py`
extracts and packages them with uniform scale, baseline, palette, and transparency.
The [pixel-art animal reference](https://virtuall.pro/blog/pixel-art-animals)
informed the emphasis on recognizable anatomy, silhouettes, and coherent shading;
no images from that article were incorporated.
`rabbit` and `forest_sprite` are generic replacements for the reference's
branded Miffy and Totoro entries. This app is independent of both upstream
projects and has no affiliation with the character owners.

`Assets/manifest.json` records every GIF, its source, credit, license and hash.
