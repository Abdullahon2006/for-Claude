#!/usr/bin/env python3
"""Generate SwiftNotepad app icon at all required sizes."""

import math
import os
from PIL import Image, ImageDraw, ImageFont

ICON_DIR = "SwiftNotepad/Assets.xcassets/AppIcon.appiconset"

# Color palette
BG_TOP    = (30,  45,  90)   # deep navy
BG_BOT    = (15,  20,  50)   # darker navy
PAGE_COL  = (240, 244, 255)  # near-white page
FOLD_COL  = (190, 200, 230)  # slightly darker fold
RULE_COL  = (170, 185, 220)  # subtle ruled lines
PEN_BODY  = (255, 195,  50)  # golden yellow pen
PEN_TIP   = (60,  60,  60)   # dark tip
PEN_CLIP  = (220, 160,  30)  # darker gold clip
SHINE     = (255, 255, 255, 60)  # subtle highlight


def lerp_color(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def rounded_rect(draw, xy, radius, fill):
    x0, y0, x1, y1 = xy
    draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=fill)


def draw_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d   = ImageDraw.Draw(img)
    s   = size

    # --- Background: vertical gradient via horizontal bands ---
    for y in range(s):
        t   = y / s
        col = lerp_color(BG_TOP, BG_BOT, t) + (255,)
        d.line([(0, y), (s, y)], fill=col)

    # Clip background to rounded square
    mask = Image.new("L", (s, s), 0)
    md   = ImageDraw.Draw(mask)
    r    = int(s * 0.22)
    md.rounded_rectangle([0, 0, s-1, s-1], radius=r, fill=255)
    img.putalpha(mask)

    # Reapply the gradient only inside the rounded rect
    grad = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    gd   = ImageDraw.Draw(grad)
    for y in range(s):
        t   = y / s
        col = lerp_color(BG_TOP, BG_BOT, t) + (255,)
        gd.line([(0, y), (s, y)], fill=col)
    bg_mask = Image.new("L", (s, s), 0)
    bmd = ImageDraw.Draw(bg_mask)
    bmd.rounded_rectangle([0, 0, s-1, s-1], radius=r, fill=255)
    grad.putalpha(bg_mask)
    img = Image.alpha_composite(Image.new("RGBA", (s, s), (0,0,0,0)), grad)
    d   = ImageDraw.Draw(img)

    # --- Page (document) ---
    px0 = int(s * 0.20)
    py0 = int(s * 0.15)
    px1 = int(s * 0.72)
    py1 = int(s * 0.80)
    fold = int(s * 0.14)   # fold size

    # Page body (clip fold corner by drawing polygon)
    page_pts = [
        (px0, py0),
        (px1 - fold, py0),
        (px1, py0 + fold),
        (px1, py1),
        (px0, py1),
    ]
    d.polygon(page_pts, fill=PAGE_COL)

    # Fold triangle
    fold_pts = [
        (px1 - fold, py0),
        (px1, py0 + fold),
        (px1 - fold, py0 + fold),
    ]
    d.polygon(fold_pts, fill=FOLD_COL)

    # Ruled lines on the page
    margin_l = int(s * 0.09)
    margin_r = int(s * 0.08)
    line_x0  = px0 + margin_l
    line_x1  = px1 - margin_r
    line_start_y = py0 + int(s * 0.14)
    n_lines  = 4
    line_gap = int(s * 0.105)
    lw = max(1, int(s * 0.012))
    for i in range(n_lines):
        y = line_start_y + i * line_gap
        if y < py1 - int(s * 0.05):
            # Shorten last line and lines near fold
            x1 = line_x1 if y < py0 + fold else min(line_x1, px1 - fold - int(s * 0.04))
            d.line([(line_x0, y), (x1, y)], fill=RULE_COL, width=lw)

    # --- Pen / pencil (diagonal, lower-right area) ---
    pen_len  = int(s * 0.52)
    pen_w    = int(s * 0.09)
    tip_len  = int(s * 0.10)
    # Pen runs from upper-left to lower-right, ending near bottom-right of icon
    ex = int(s * 0.82)
    ey = int(s * 0.83)
    angle = math.radians(45)
    sx = ex - int(pen_len * math.cos(angle))
    sy = ey - int(pen_len * math.sin(angle))

    dx   = math.cos(angle)
    dy   = math.sin(angle)
    perp = (-dy, dx)
    hw   = pen_w / 2

    def pen_corner(ox, oy, along, across):
        return (
            int(ox + along * dx + across * perp[0] * hw),
            int(oy + along * dy + across * perp[1] * hw),
        )

    # Pen body
    body = [
        pen_corner(sx, sy,  0,  1),
        pen_corner(sx, sy,  0, -1),
        pen_corner(ex, ey, -tip_len, -1),
        pen_corner(ex, ey, -tip_len,  1),
    ]
    d.polygon(body, fill=PEN_BODY)

    # Pen clip (darker stripe along body)
    clip_w = 0.15
    clip = [
        pen_corner(sx, sy,  int(s*0.02),  clip_w),
        pen_corner(sx, sy,  int(s*0.02), -clip_w),
        pen_corner(ex, ey, -tip_len,     -clip_w),
        pen_corner(ex, ey, -tip_len,      clip_w),
    ]
    d.polygon(clip, fill=PEN_CLIP)

    # Tip (dark triangle)
    tip = [
        pen_corner(ex, ey, -tip_len,  1),
        pen_corner(ex, ey, -tip_len, -1),
        (ex, ey),
    ]
    d.polygon(tip, fill=PEN_TIP)

    # Subtle top-left shine on background
    shine_r = int(s * 0.28)
    shine_img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shine_img)
    sd.ellipse([-shine_r, -shine_r, shine_r, shine_r], fill=(255, 255, 255, 30))
    img = Image.alpha_composite(img, shine_img)

    return img


SIZES = [16, 32, 64, 128, 256, 512, 1024]

os.makedirs(ICON_DIR, exist_ok=True)

generated = []
for sz in SIZES:
    filename = f"icon_{sz}x{sz}.png"
    path = os.path.join(ICON_DIR, filename)
    draw_icon(sz).save(path, "PNG")
    generated.append((sz, filename))
    print(f"  Generated {filename}")

# Write Contents.json
entries = []
specs = [
    ("16",  "1x", 16),
    ("16",  "2x", 32),
    ("32",  "1x", 32),
    ("32",  "2x", 64),
    ("128", "1x", 128),
    ("128", "2x", 256),
    ("256", "1x", 256),
    ("256", "2x", 512),
    ("512", "1x", 512),
    ("512", "2x", 1024),
]
for pt, scale, px in specs:
    filename = f"icon_{px}x{px}.png"
    entries.append(f"""    {{
      "filename" : "{filename}",
      "idiom" : "mac",
      "scale" : "{scale}",
      "size" : "{pt}x{pt}"
    }}""")

contents = '{\n  "images" : [\n' + ',\n'.join(entries) + '\n  ],\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n'
with open(os.path.join(ICON_DIR, "Contents.json"), "w") as f:
    f.write(contents)

print("Done — Contents.json updated.")
