#!/usr/bin/env python3
"""Generate MATRIX digital-rain wallpapers with ImageMagick (no PIL needed).

usage: gen_rain.py <variant> <out.jpg> [seed]
variants: classic, neo, logo, depth
"""
import os, random, subprocess, sys, tempfile

W, H = 1920, 1200
CJK = "/usr/share/fonts/noto-cjk/NotoSansCJK-Medium.ttc"
CJKB = "/usr/share/fonts/noto-cjk/NotoSansCJK-Bold.ttc"
MONO = os.path.expanduser("~/.local/share/fonts/HurmitNerdFont/HurmitNerdFont-Bold.otf")
GLYPHS = [chr(c) for c in range(0xFF66, 0xFF9E)] + list("0123456789") + list("Z:.=*+-<>|")


def esc(s):
    return s.replace("\\", "\\\\").replace("'", "\\'")


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return "#%02x%02x%02x" % tuple(int(a[i] * (1 - t) + b[i] * t + 0.5) for i in range(3))


BLACK = (0, 6, 2)
DARK = (0, 59, 0)
MID = (0, 143, 17)
GREEN = (0, 255, 65)
LIGHT = (125, 255, 154)
WHITE = (234, 255, 234)


def tail_color(k, L, dim=1.0):
    """k=0 is the leading glyph."""
    if k == 0:
        c = mix(LIGHT, WHITE, 1.0)
    elif k <= 2:
        c = mix(GREEN, LIGHT, 0.6 - 0.2 * k)
    else:
        f = (1 - k / L) ** 1.4
        c = mix(DARK, GREEN, f ** 0.8) if f > 0.18 else mix(BLACK, DARK, min(1.0, f / 0.18 + 0.25))
    if dim < 1.0:
        rgb = tuple(int(c[i:i + 2], 16) for i in (1, 3, 5))
        c = mix(BLACK, rgb, dim)
    return c


def glyph(out, x, y, size, color, g=None, cw=None):
    g = g or random.choice(GLYPHS)
    cw = cw or size
    if random.random() < 0.5:  # mirrored katakana, like the film
        out.append(f"push graphic-context affine -1 0 0 1 {x + cw:.1f} 0 fill '{color}' text 0,{y:.1f} '{esc(g)}' pop graphic-context")
    else:
        out.append(f"fill '{color}' text {x:.1f},{y:.1f} '{esc(g)}'")


def rain_layer(size, density, dim=1.0, font=CJK, mask=None):
    """Return MVG primitives for one layer of rain. mask(col,row)->bool marks lit logo cells."""
    cw = size * 1.08
    ch = size * 1.18
    cols = int(W / cw) + 1
    rows = int(H / ch) + 2
    out = [f"font '{font}'", f"font-size {size}"]
    for c in range(cols):
        x = c * cw + (cw - size) / 2
        lit = [False] * rows
        drops = 0 if random.random() > density else random.choice([1, 1, 2, 2, 3])
        for _ in range(drops):
            head = random.randint(-5, rows + 10)
            L = random.randint(6, max(8, rows // 2))
            for k in range(L):
                r = head - k
                if 0 <= r < rows and not lit[r]:
                    lit[r] = True
                    if mask and mask(c, r):
                        continue
                    glyph(out, x, (r + 1) * ch, size, tail_color(k, L, dim), cw=size)
        # faint stale residue
        for r in range(rows):
            if not lit[r] and random.random() < 0.05 * density and not (mask and mask(c, r)):
                glyph(out, x, (r + 1) * ch, size, mix(BLACK, DARK, 0.45 * dim), cw=size)
        if mask:
            for r in range(rows):
                if mask(c, r):
                    bright = random.random()
                    col = mix(MID, GREEN, bright) if bright < 0.93 else mix(GREEN, WHITE, 0.8)
                    glyph(out, x, (r + 1) * ch, size, col, cw=size)
    return out, cols, rows


def render(mvg_lines, out_png):
    with tempfile.NamedTemporaryFile("w", suffix=".mvg", delete=False, encoding="utf-8") as f:
        f.write(f"viewbox 0 0 {W} {H}\n")
        f.write("\n".join(mvg_lines))
        path = f.name
    subprocess.run(["magick", "-size", f"{W}x{H}", "xc:#000602", "-draw", f"@{path}", out_png], check=True)
    os.unlink(path)


def glow(src, dst, sigma=5, extra=""):
    cmd = ["magick", src, "(", "+clone", "-blur", f"0x{sigma}", ")", "-compose", "screen", "-composite"]
    cmd += ["(", "+clone", "-blur", f"0x{sigma * 3}", "-evaluate", "multiply", "0.6", ")", "-compose", "screen", "-composite", dst]
    subprocess.run(cmd, check=True)


def finish(src, dst):
    """Vignette + faint CRT scanlines, save as a reasonably sized JPG."""
    subprocess.run([
        "magick", src,
        "(", "-size", f"{W}x{H}", "radial-gradient:#ffffff-#4a4a4a", "-resize", "130%", "-gravity", "center", "-extent", f"{W}x{H}", ")",
        "-compose", "multiply", "-composite",
        "(", "-size", "1x3", "xc:white", "-fill", "#e8e8e8", "-draw", "point 0,2", "-write", "mpr:scan", "+delete",
        "-size", f"{W}x{H}", "tile:mpr:scan", ")",
        "-compose", "multiply", "-composite",
        "-quality", "88", "-sampling-factor", "4:2:0", "-strip", dst,
    ], check=True)


def omarchy_mask():
    art = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "omarchy-logo.txt"), encoding="utf-8").read().splitlines()
    art = [l for l in art if l.strip()]
    aw = max(len(l) for l in art)
    ah = len(art)
    return art, aw, ah


def main():
    variant, out = sys.argv[1], sys.argv[2]
    random.seed(int(sys.argv[3]) if len(sys.argv) > 3 else 1999)
    tmp = tempfile.mkdtemp()
    raw, glowed = os.path.join(tmp, "raw.png"), os.path.join(tmp, "glow.png")

    if variant == "classic":
        lines, _, _ = rain_layer(26, 0.9, font=CJKB)
        render(lines, raw)
        glow(raw, glowed, 4)

    elif variant == "depth":
        lines = []
        lines += rain_layer(12, 0.7, dim=0.35)[0]
        lines += rain_layer(18, 0.45, dim=0.6)[0]
        render(lines, raw)
        subprocess.run(["magick", raw, "-blur", "0x1.2", raw], check=True)
        near = os.path.join(tmp, "near.png")
        fl, _, _ = rain_layer(34, 0.25, font=CJKB)
        render(fl, near)
        subprocess.run(["magick", raw, near, "-compose", "lighten", "-composite", raw], check=True)
        glow(raw, glowed, 5)

    elif variant == "logo":
        art, aw, ah = omarchy_mask()
        size = 20
        cw, ch = size * 1.08, size * 1.18
        cols, rows = int(W / cw) + 1, int(H / ch) + 2
        # each art char = 1 col; art rows are ~2 cells tall in the terminal, ours are square-ish
        sx = 1
        ox = (cols - aw * sx) // 2
        oy = (rows - ah) // 2

        def mask(c, r):
            ac = (c - ox) // sx
            ar = r - oy
            if 0 <= ar < ah and 0 <= ac < len(art[ar]):
                return art[ar][ac] not in " "
            return False

        lines, _, _ = rain_layer(size, 0.75, dim=0.6, font=CJKB, mask=mask)
        render(lines, raw)
        glow(raw, glowed, 4)
        # glitch: a few horizontal slices knocked sideways
        cmd = ["magick", glowed]
        for _ in range(7):
            y = random.randint(int(H * 0.25), int(H * 0.75))
            h = random.randint(4, 26)
            dx = random.choice([-1, 1]) * random.randint(8, 40)
            cmd += ["-region", f"{W}x{h}+0+{y}", "-roll", f"{dx:+d}+0", "+region"]
        cmd += [glowed]
        subprocess.run(cmd, check=True)

    elif variant == "neo":
        lines, _, _ = rain_layer(24, 0.85, dim=0.4, font=CJKB)
        render(lines, raw)
        glow(raw, glowed, 4)
        cy = H // 2 - 60
        txt = os.path.join(tmp, "txt.png")
        subprocess.run([
            "magick", "-size", f"{W}x{H}", "xc:black", "-font", MONO,
            "-fill", "#00ff41", "-pointsize", "76", "-gravity", "center",
            "-annotate", f"+0{cy - H // 2:+d}", "Wake up, Neo...█",
            "-fill", "#2fcf5a", "-pointsize", "30",
            "-annotate", f"+0{cy - H // 2 + 110:+d}", "The Matrix has you...",
            "-annotate", f"+0{cy - H // 2 + 160:+d}", "Follow the white rabbit.",
            "-fill", "#7dff9a",
            "-annotate", f"+0{cy - H // 2 + 230:+d}", "Knock, knock, Neo.",
            "(", "+clone", "-blur", "0x8", ")", "-compose", "screen", "-composite",
            "(", "+clone", "-blur", "0x24", ")", "-compose", "screen", "-composite",
            txt,
        ], check=True)
        # dark band behind the text so it reads cleanly
        subprocess.run([
            "magick", glowed,
            "(", "-size", f"{W}x{H}", "xc:white", "-fill", "#303030", "-draw", f"rectangle 0,{cy - 90} {W},{cy + 300}", "-blur", "0x60", ")",
            "-compose", "multiply", "-composite", txt, "-compose", "screen", "-composite", glowed,
        ], check=True)
    else:
        sys.exit("unknown variant")

    finish(glowed, out)


if __name__ == "__main__":
    main()
