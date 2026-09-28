# Third-party artwork

All current dog GIFs are original project artwork. Earlier releases used four
unmodified NVPH Studio dog sets under CC BY-ND 4.0; those sprites and their
license remain in Git history and are no longer included in the app.

The Realistic horse GIFs are artwork by [Onfe](https://onfe.itch.io/horse-sprite-with-rider-asset-pack),
adapted by [Chris Kent](https://github.com/thechriskent) for VS Code Pets at commit
`2c91214beb922288cca1938cddb607abc5f806b7`. Onfe permits personal/commercial project use and edits with credit,
and explicitly allows sharing GIFs in project repositories. These GIF bytes are
unchanged; the standing animation is also used for the horse's resting state.
The permission and source details are recorded in `Assets/horse/license.txt`.

The other 174 Realistic GIFs and all 210 Pixel GIFs were created for this project
using OpenAI's built-in image generation tool. The 22 Realistic RGBA sheets are
in `Artwork/`; the 35 Pixel sheets are in `Artwork/Pixel/`, including original
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
