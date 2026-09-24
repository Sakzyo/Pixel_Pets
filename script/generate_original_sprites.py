"""Package original Realistic (128 px) or Pixel (32 px) artwork as GIFs.

Requires Pillow. Sheets, generation prompts and reviewed frame bounds are checked
in together; regenerating never calls a service or redraws the animals.
"""

import argparse
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


def prepare_frames(sheet, bounds, size=SIZE, margin=MARGIN, color_count=255):
    # One scale for the entire animal prevents its size changing between poses.
    extent = max(max(right-left, bottom-top) for left, top, right, bottom in bounds)
    scale = (size - 2*margin) / extent
    frames = []
    for box in bounds:
        artwork = sheet.crop(box)
        artwork = artwork.resize((max(1, round(artwork.width*scale)),
                                  max(1, round(artwork.height*scale))), Image.Resampling.NEAREST)
        frame = Image.new("RGBA", (size, size))
        frame.paste(artwork, ((size-artwork.width)//2, size-margin-artwork.height))
        frame.paste((0, 0, 0, 0), mask=frame.getchannel("A").point(lambda alpha: 255 if alpha < 128 else 0))
        frames.append(frame)

    # Share the palette across actions to keep fur and markings from flickering.
    strip = Image.new("RGB", (size*len(frames), size))
    for index, frame in enumerate(frames):
        strip.paste(frame.convert("RGB"), (size*index, 0))
    palette = strip.quantize(colors=color_count, method=Image.Quantize.MAXCOVERAGE, dither=Image.Dither.NONE)
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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--style", choices=("realistic", "pixel"), default="realistic")
    style = parser.parse_args().style
    pixel = style == "pixel"
    artwork_folder = PROJECT / ("Artwork/Pixel" if pixel else "Artwork")
    asset_folder = PROJECT / ("Assets/Pixel" if pixel else "Assets")
    specs = json.loads((artwork_folder / "sheets.json").read_text())
    count = 0
    for spec in specs:
        sheet = Image.open(artwork_folder / spec["file"]).convert("RGBA")
        for variant, bounds in zip(spec["variants"], spec["frames"], strict=True):
            assert len(bounds) == 8, (spec["id"], variant)
            frames = prepare_frames(sheet, bounds, size=32 if pixel else SIZE,
                                    margin=2 if pixel else MARGIN, color_count=15 if pixel else 255)
            folder = asset_folder / spec["species"]
            folder.mkdir(parents=True, exist_ok=True)
            for state, (indices, durations) in ANIMATIONS.items():
                selected = [frames[index] for index in indices]
                selected[0].save(folder / f"{variant}_{state}_8fps.gif", save_all=True,
                                 append_images=selected[1:], duration=durations, loop=0,
                                 transparency=0, disposal=2, optimize=False)
                count += 1
    print(f"Packaged {count} original {style} GIFs; third-party GIFs untouched")


if __name__ == "__main__":
    main()
