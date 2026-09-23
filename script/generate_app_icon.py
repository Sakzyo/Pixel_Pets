#!/usr/bin/env python3
"""Draw the original Desktop Pets app icon and package its macOS sizes."""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "Config"
SIZE = 1024

gradient = Image.new("RGBA", (SIZE, SIZE))
pixels = gradient.load()
for y in range(SIZE):
    amount = y / (SIZE - 1)
    color = tuple(round(top * (1 - amount) + bottom * amount) for top, bottom in
                  zip((26, 100, 119), (12, 42, 65))) + (255,)
    for x in range(SIZE):
        pixels[x, y] = color

mask = Image.new("L", (SIZE, SIZE))
ImageDraw.Draw(mask).rounded_rectangle((52, 52, 972, 972), radius=210, fill=255)
gradient.putalpha(mask)
draw = ImageDraw.Draw(gradient)
draw.rounded_rectangle((58, 58, 966, 966), radius=204, outline=(132, 208, 207, 160), width=10)

paw = Image.new("RGBA", (40, 40))
draw = ImageDraw.Draw(paw)
outline = (98, 49, 49, 255)
fur = (255, 189, 115, 255)
highlight = (255, 225, 159, 255)
draw.polygon([(12, 19), (16, 16), (24, 16), (28, 19), (31, 26), (29, 32),
              (25, 34), (15, 34), (11, 32), (9, 26)], fill=outline)
draw.polygon([(13, 21), (17, 18), (23, 18), (27, 21), (29, 27), (27, 30),
              (24, 32), (16, 32), (13, 30), (11, 27)], fill=fur)
draw.rectangle((16, 22, 24, 25), fill=highlight)
for box in ((4, 13, 11, 21), (11, 7, 18, 16), (21, 7, 28, 16), (28, 13, 35, 21)):
    draw.rounded_rectangle(box, radius=2, fill=outline)
    draw.rounded_rectangle((box[0] + 2, box[1] + 2, box[2] - 2, box[3] - 2),
                           radius=1, fill=highlight)

gradient.alpha_composite(paw.resize((640, 640), Image.Resampling.NEAREST), (192, 192))
png = CONFIG / "AppIcon.png"
gradient.save(png)
gradient.save(CONFIG / "AppIcon.icns", format="ICNS")
