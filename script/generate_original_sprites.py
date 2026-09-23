"""Package the original artwork in Artwork/ into transparent 128 px GIFs.

Requires Pillow. Sheets, generation prompts and reviewed frame bounds are checked
in together; regenerating never calls a service or redraws the animals.
"""

import json
from pathlib import Path
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
SIZE = 128
MARGIN = 6
# Indices refer to idle, blink, two steps, run, greet, sleep, and ball poses.
ANIMATIONS = {
    "idle": ([0, 1, 0], [1750, 125, 625]),
    "walk": ([2, 0, 3, 0], [125] * 4),
    "run": ([4, 2, 4, 3], [125] * 4),
    "swipe": ([0, 5, 0, 5], [125, 250, 125, 250]),
    "lie": ([6], [1000]),
    "with_ball": ([7], [1000]),
}


def prepare_frames(sheet, bounds):
    # One scale for the entire animal prevents its size changing between poses.
    extent = max(max(right-left, bottom-top) for left, top, right, bottom in bounds)
    scale = (SIZE - 2*MARGIN) / extent
    frames = []
    for box in bounds:
        artwork = sheet.crop(box)
        artwork = artwork.resize((max(1, round(artwork.width*scale)),
                                  max(1, round(artwork.height*scale))), Image.Resampling.NEAREST)
        frame = Image.new("RGBA", (SIZE, SIZE))
        frame.paste(artwork, ((SIZE-artwork.width)//2, SIZE-MARGIN-artwork.height))
        frame.paste((0, 0, 0, 0), mask=frame.getchannel("A").point(lambda alpha: 255 if alpha < 128 else 0))
        frames.append(frame)

    # Share the palette across actions to keep fur and markings from flickering.
    strip = Image.new("RGB", (SIZE*len(frames), SIZE))
    for index, frame in enumerate(frames):
        strip.paste(frame.convert("RGB"), (SIZE*index, 0))
    palette = strip.quantize(colors=255, method=Image.Quantize.MAXCOVERAGE, dither=Image.Dither.NONE)
    colors = [0, 0, 0] + palette.getpalette()[:765]
    indexed = []
    for frame in frames:
        image = frame.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE)
        image = image.point(lambda index: index+1)
        image.putpalette(colors)
        # GIF supports binary transparency. Keep its reserved index out of the fur.
        image.paste(0, mask=frame.getchannel("A").point(lambda alpha: 255 if alpha < 128 else 0))
        image.info["transparency"] = 0
        indexed.append(image)
    return indexed


def main():
    specs = json.loads((PROJECT / "Artwork/sheets.json").read_text())
    count = 0
    for spec in specs:
        sheet = Image.open(PROJECT / "Artwork" / spec["file"]).convert("RGBA")
        for variant, bounds in zip(spec["variants"], spec["frames"], strict=True):
            assert len(bounds) == 8, (spec["id"], variant)
            frames = prepare_frames(sheet, bounds)
            folder = PROJECT / "Assets" / spec["species"]
            folder.mkdir(parents=True, exist_ok=True)
            for state, (indices, durations) in ANIMATIONS.items():
                selected = [frames[index] for index in indices]
                selected[0].save(folder / f"{variant}_{state}_8fps.gif", save_all=True,
                                 append_images=selected[1:], duration=durations, loop=0,
                                 transparency=0, disposal=2, optimize=False)
                count += 1
    print(f"Packaged {count} original GIFs; upstream dog GIFs untouched")


if __name__ == "__main__":
    main()
