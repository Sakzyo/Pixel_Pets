# Animal artwork

![Representative bundled animal sprites](catalog-preview.png)

The original sheets in this folder were created with the built-in OpenAI image
generation tool. `sheets.json` contains every exact prompt, file name, species,
variant order, and reviewed pixel bounds for the eight poses. No API/CLI fallback
was used. These source sheets are project assets; only the GIFs in `Assets/` are
included in the app bundle.

The visual reference was https://virtuall.pro/blog/pixel-art-animals. Its emphasis
on recognizable silhouettes, animal anatomy, purposeful palettes, and consistent
shading guided the new drawings. No artwork from that page was copied.

The poses are idle, blink, two walking steps, running, greeting, sleeping, and
playing with a ball. The packager gives all eight poses of each animal one scale
and a common baseline, preserves aspect ratio, and places them in 128 px canvases.
The shared palette uses maximum coverage to preserve small colored details such
as the green ball. GIFs use a reserved transparent index and no dithering.

Regenerate the 120 original GIFs with Pillow installed:

```sh
python3 script/generate_original_sprites.py
python3 script/write_asset_manifest.py
./script/test.sh
```

The 66 horse GIFs come from Onfe's artwork, adapted by Chris Kent in VS Code Pets
at commit `2c91214beb922288cca1938cddb607abc5f806b7`; they retain the supplied 80 × 64
pixel frames and animations. The horse rests using the standing animation. See
`Assets/horse/license.txt` and `Assets/manifest.json` for credit and exact sources.
Four dog color sets also retain their original GIF bytes and separate license.
The packager never overwrites those third-party assets.
