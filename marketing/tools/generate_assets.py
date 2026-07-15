#!/usr/bin/env python3
"""Beatter store-asset generator (v2 — real app screenshots).

Composes the marketing package for App Store + Google Play from REAL app
screenshots (captured by marketing/automation/capture_real_screens.js from
the running app) framed in a clean device mockup, plus two 100%-advertising
brand images that use no app GUI at all.

Renders via headless Chrome at pixel-exact store dimensions.

Usage:
    python3 marketing/tools/generate_assets.py [--only id] [--sizes phone|tablet|graphics|all]
"""

import argparse
import base64
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # marketing/
PROJECT = os.path.dirname(ROOT)
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def data_uri(path):
    with open(path, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode()


LOGO_URI = data_uri(os.path.join(PROJECT, "assets", "logos", "logo_beatter.png"))
SHOTS_PHONE = os.path.join(ROOT, "screenshots", "phones")
SHOTS_TABLET = os.path.join(ROOT, "screenshots", "tablets")

# ------------------------------------------------------------------- sizes --
SIZES = [
    ("app_store/iphone_6_9",  1320, 2868, "phone"),
    ("app_store/iphone_6_7",  1290, 2796, "phone"),
    ("app_store/iphone_6_5",  1242, 2688, "phone"),
    ("app_store/iphone_6_3",  1179, 2556, "phone"),
    ("app_store/iphone_5_5",  1242, 2208, "phone"),
    ("app_store/ipad_13_portrait",  2064, 2752, "tablet_p"),
    ("app_store/ipad_13_landscape", 2752, 2064, "tablet_l"),
    ("app_store/ipad_11_portrait",  1668, 2388, "tablet_p"),
    ("app_store/ipad_11_landscape", 2388, 1668, "tablet_l"),
    ("play_store/phones",             1080, 1920, "phone"),
    ("play_store/tablets/10_portrait",  1600, 2560, "tablet_p"),
    ("play_store/tablets/10_landscape", 2560, 1600, "tablet_l"),
    ("play_store/tablets/7_portrait",   1200, 1920, "tablet_p"),
]

# ------------------------------------------------------------- shared CSS ---
BASE_CSS = """
* { margin:0; padding:0; box-sizing:border-box; }
html,body { width:100vw; height:100vh; overflow:hidden;
  font-family:-apple-system,'SF Pro Display','Helvetica Neue',sans-serif;
  -webkit-font-smoothing:antialiased; }

body { background:linear-gradient(170deg,#FFF8F1 0%,#FFF0E0 55%,#FFE3C4 100%); }
body.accent { background:linear-gradient(160deg,#FF8E1F 0%,#FF7A00 40%,#C1502E 100%); }

/* ---- decorative layer ---- */
.decor { position:absolute; inset:0; overflow:hidden; z-index:0; }
.glow { position:absolute; border-radius:50%; filter:blur(9vmin); opacity:.55; }
.g1 { width:70vmin; height:70vmin; top:-18vmin; right:-20vmin; background:#FFC266; }
.g2 { width:60vmin; height:60vmin; bottom:8vmin; left:-22vmin; background:#FFA347; opacity:.4; }
body.accent .g1 { background:#FFD9A0; opacity:.35; }
body.accent .g2 { background:#8f2f12; opacity:.45; }
.note { position:absolute; font-weight:700; color:#FF7A00; opacity:.14; user-select:none; }
body.accent .note { color:#FFF; opacity:.22; }
.ring { position:absolute; border:.45vmin dashed #FF7A00; border-radius:50%; opacity:.18; }
body.accent .ring { border-color:#FFF; opacity:.28; }

/* ---- page layout ---- */
.page { position:relative; z-index:1; width:100vw; height:100vh;
  display:flex; flex-direction:column; align-items:center; }

.copy { text-align:center; padding:6.5vh 8vw 0; }
.headline { font-size:7.2vw; line-height:1.06; font-weight:800;
  letter-spacing:-.02em; color:#2D2D2D; }
.sub { margin-top:1.9vh; font-size:3.3vw; line-height:1.35; font-weight:500; color:#666; }
body.accent .headline { color:#FFF; }
body.accent .sub { color:#FFEAD1; }

/* device fully visible, vertically centered in the remaining space */
.stage { flex:1; width:100%; display:flex; justify-content:center;
  align-items:center; padding:4vh 0 5vh; }

.device { position:relative; background:#1b1b1d;
  box-shadow:0 5vmin 12vmin rgba(94,38,0,.35), 0 1.2vmin 3.5vmin rgba(94,38,0,.22); }
.device img.screen { display:block; width:100%; height:100%;
  object-fit:cover; }

.device.phone { height:66vh; aspect-ratio: 448 / 950;
  border-radius:3.6vh; padding:.55vh; }
.device.phone .clip { border-radius:3.1vh; overflow:hidden; width:100%; height:100%; }

.device.tablet { height:62vh; aspect-ratio: 1056 / 1398;
  border-radius:3vh; padding:.8vh; }
.device.tablet .clip { border-radius:2.3vh; overflow:hidden; width:100%; height:100%; }

/* phone 16:9 exports: slightly smaller type, same layout */
body.layout-phone.wide .headline { font-size:6vw; }
body.layout-phone.wide .sub { font-size:2.8vw; }
body.layout-phone.wide .copy { padding-top:5vh; }
body.layout-phone.wide .device.phone { height:62vh; }

/* tablet portrait */
body.layout-tablet_p .headline { font-size:6vw; }
body.layout-tablet_p .sub { font-size:2.6vw; }
body.layout-tablet_p .stage { padding:3.5vh 0 4.5vh; }

/* tablet landscape: copy left, device right, everything visible */
body.layout-tablet_l .page { flex-direction:row; align-items:stretch; }
body.layout-tablet_l .copy { flex:0 0 40vw; text-align:left;
  display:flex; flex-direction:column; justify-content:center;
  padding:0 0 0 7vw; }
body.layout-tablet_l .headline { font-size:5.4vw; }
body.layout-tablet_l .sub { font-size:2.1vw; margin-top:3vh; max-width:27vw; }
body.layout-tablet_l .stage { padding:6vh 6vw 6vh 0; }
/* the captures are portrait; show a portrait tablet beside the copy */
body.layout-tablet_l .device.tablet { height:80vh; }
body.layout-tablet_l .badge { display:inline-flex; }

.badge { display:none; align-items:center; gap:1vw; margin-bottom:4vh; }
.badge img { width:4.4vw; height:4.4vw; }
.badge span { font-size:2.5vw; font-weight:800; color:#2D2D2D; letter-spacing:-.01em; }
body.accent .badge span { color:#FFF; }
"""

DECOR = """
<div class="decor">
  <div class="glow g1"></div><div class="glow g2"></div>
  <div class="note" style="top:9vh;left:6vw;font-size:7vmin;transform:rotate(-14deg)">♪</div>
  <div class="note" style="top:24vh;right:5vw;font-size:9vmin;transform:rotate(10deg)">♫</div>
  <div class="note" style="bottom:14vh;left:4vw;font-size:8vmin;transform:rotate(8deg)">♩</div>
  <div class="note" style="bottom:30vh;right:6vw;font-size:6vmin;transform:rotate(-8deg)">♬</div>
  <div class="ring" style="width:34vmin;height:34vmin;bottom:-10vmin;right:-8vmin"></div>
  <div class="ring" style="width:22vmin;height:22vmin;top:16vh;left:-7vmin"></div>
</div>"""

# ----------------------------------------------------------------- screens --
# kind "shot": real screenshot in a device frame.
# kind "ad":   100% advertising composition, no app GUI.
SCREENS = [
    dict(id="01_brand", kind="ad", ad="brand", accent=True,
         headline="Allenati con il ritmo.",
         sub="Il rhythm trainer per batteristi, musicisti e studenti."),
    dict(id="02_home", kind="shot", shot="home", accent=False,
         headline="Tutto il tuo allenamento.",
         sub="Flow, lettura, poliritmi e ascolto in un'unica app."),
    dict(id="03_flow_mode", kind="shot", shot="flow_mode", accent=False,
         headline="Allenamenti intelligenti.",
         sub="Ritmi generati su misura: ogni sessione migliora il tuo timing."),
    dict(id="04_poliritmi", kind="shot", shot="polyrhythm_lab", accent=False,
         headline="Visualizza i poliritmi.",
         sub="Capisci quello che senti, non contarlo: vivilo."),
    dict(id="05_livelli", kind="shot", shot="sheet_generator", accent=False,
         headline="Dal principiante al professionista.",
         sub="Cinque livelli di difficoltà, esercizi sempre nuovi."),
    dict(id="06_lettura", kind="shot", shot="sheet_mode", accent=False,
         headline="Padroneggia la lettura.",
         sub="Esercizi sul pentagramma, esportabili in PDF."),
    dict(id="07_ascolta_ripeti", kind="shot", shot="reading_mode", accent=False,
         headline="Ascolta. Ripeti. Migliora.",
         sub="L'esercizio si ferma: tocca a te rifare il ritmo."),
    dict(id="08_precisione", kind="ad", ad="precision", accent=True,
         headline="Massima precisione.",
         sub="Ogni millisecondo fa la differenza."),
]


def shot_uri(name, kind):
    base = SHOTS_TABLET if kind != "phone" else SHOTS_PHONE
    p = os.path.join(base, name + ".png")
    if not os.path.exists(p):  # tablet capture missing → fall back to phone
        p = os.path.join(SHOTS_PHONE, name + ".png")
    return data_uri(p)


# ---------------------------------------------------------- ad compositions --
def ad_brand_body():
    """Pure-brand hero: logo, wordmark, rhythm bars. No GUI."""
    bars = "".join(
        '<div style="width:1.6vw;height:%dvh;border-radius:100vmax;background:rgba(255,255,255,%s)"></div>'
        % (h, o) for h, o in
        [(6, .45), (11, .7), (8, .55), (15, .9), (10, .65), (18, 1), (12, .75),
         (8, .55), (14, .85), (10, .65), (6, .45)])
    return """
    <div class="stage" style="flex-direction:column;gap:5vh;padding:2vh 0 6vh">
      <img src="%s" style="width:44vw;filter:drop-shadow(0 3vh 6vh rgba(94,38,0,.35))">
      <div style="font-size:13vw;font-weight:800;color:#FFF;letter-spacing:-.02em;line-height:1">Beatter</div>
      <div style="display:flex;align-items:flex-end;gap:1.6vw;height:18vh">%s</div>
    </div>""" % (LOGO_URI, bars)


def ad_precision_body():
    """Typographic precision claim over a tick ruler. No GUI."""
    ticks = "".join(
        '<div style="width:.5vw;height:%s;border-radius:100vmax;background:rgba(255,255,255,%s)"></div>'
        % ("9vh" if i == 10 else ("5.5vh" if i % 5 == 0 else "3.2vh"),
           "1" if i == 10 else ".55")
        for i in range(21))
    return """
    <div class="stage" style="flex-direction:column;gap:6vh;padding:2vh 0 6vh">
      <div style="display:flex;align-items:center;gap:1.2vw">%s</div>
      <div style="font-size:24vw;font-weight:800;color:#FFF;letter-spacing:-.04em;line-height:1">±5<span style="font-size:8vw;font-weight:700;color:#FFEAD1"> ms</span></div>
      <div style="display:flex;gap:2.6vw">
        <span style="padding:1.6vh 2.6vw;border-radius:100vmax;background:rgba(255,255,255,.16);border:.3vh solid rgba(255,255,255,.45);color:#FFF;font-weight:700;font-size:2.9vw">Feedback immediato</span>
        <span style="padding:1.6vh 2.6vw;border-radius:100vmax;background:rgba(255,255,255,.16);border:.3vh solid rgba(255,255,255,.45);color:#FFF;font-weight:700;font-size:2.9vw">Record personali</span>
      </div>
      <img src="%s" style="width:13vw;opacity:.95">
    </div>""" % (ticks, LOGO_URI)


def page_html(screen, kind, w, h):
    body_cls = ["layout-" + ("phone" if kind == "phone" else kind)]
    if screen["accent"]:
        body_cls.append("accent")
    if kind == "phone" and w / h > 0.52:
        body_cls.append("wide")
    badge = ('<div class="badge"><img src="%s"><span>Beatter</span></div>' % LOGO_URI)

    if screen["kind"] == "ad":
        body = ad_brand_body() if screen["ad"] == "brand" else ad_precision_body()
        stage = body
    else:
        device_cls = "phone" if kind == "phone" else "tablet"
        stage = """
        <div class="stage"><div class="device %s">
          <div class="clip"><img class="screen" src="%s"></div>
        </div></div>""" % (device_cls, shot_uri(screen["shot"], kind))

    return """<!doctype html><html><head><meta charset="utf-8"><style>%s</style></head>
<body class="%s">%s
<div class="page">
  <div class="copy">%s<div class="headline">%s</div><div class="sub">%s</div></div>
  %s
</div></body></html>""" % (BASE_CSS, " ".join(body_cls), DECOR, badge,
                           screen["headline"], screen["sub"], stage)


# ------------------------------------------------------- special graphics ---
def feature_graphic_html(w, h, variant="feature"):
    bars = "".join(
        '<div style="width:%.2fvw;height:%dvh;border-radius:100vmax;background:rgba(255,255,255,%s)"></div>'
        % (0.9, hh, o) for hh, o in
        [(18, .5), (34, .75), (24, .6), (46, .95), (30, .7), (54, 1), (38, .8),
         (26, .6), (44, .9), (32, .7), (20, .5), (40, .85), (28, .65), (16, .45)])
    if variant == "promo":
        return """<!doctype html><html><head><meta charset="utf-8"><style>%s</style></head>
<body class="accent"><div class="decor"><div class="glow g1"></div><div class="glow g2"></div></div>
<div style="position:relative;z-index:1;width:100vw;height:100vh;display:flex;align-items:center;justify-content:center;gap:6vw">
  <img src="%s" style="height:70vh"><div style="font-size:26vh;font-weight:800;color:#FFF;letter-spacing:-.02em">Beatter</div>
</div></body></html>""" % (BASE_CSS, LOGO_URI)
    return """<!doctype html><html><head><meta charset="utf-8"><style>%s</style></head>
<body class="accent"><div class="decor"><div class="glow g1"></div><div class="glow g2"></div>
  <div class="note" style="top:8vh;right:26vw;font-size:11vh;transform:rotate(10deg)">♫</div>
  <div class="note" style="bottom:10vh;left:30vw;font-size:9vh;transform:rotate(-10deg)">♪</div>
  <div class="ring" style="width:60vh;height:60vh;top:-22vh;left:-12vh"></div></div>
<div style="position:relative;z-index:1;width:100vw;height:100vh;display:flex;align-items:center;padding:0 6vw;gap:5vw">
  <img src="%s" style="height:58vh;filter:drop-shadow(0 3vh 5vh rgba(94,38,0,.35))">
  <div style="flex:1">
    <div style="font-size:16vh;font-weight:800;color:#FFF;letter-spacing:-.02em;line-height:1">Beatter</div>
    <div style="font-size:9.5vh;font-weight:700;color:#FFEAD1;margin-top:2.5vh;letter-spacing:-.01em">Il ritmo, allenato.</div>
    <div style="font-size:5.2vh;font-weight:600;color:rgba(255,255,255,.85);margin-top:2.8vh">Metronomo evoluto • Poliritmi • Lettura • Esercizi progressivi</div>
  </div>
  <div style="display:flex;align-items:center;gap:.9vw;height:100%%">%s</div>
</div></body></html>""" % (BASE_CSS, LOGO_URI, bars)


def background_html(accent):
    return """<!doctype html><html><head><meta charset="utf-8"><style>%s</style></head>
<body class="%s"><div class="decor"><div class="glow g1"></div><div class="glow g2"></div>
  <div class="note" style="top:12vh;left:8vw;font-size:8vmin;transform:rotate(-12deg)">♪</div>
  <div class="note" style="top:30vh;right:10vw;font-size:10vmin;transform:rotate(9deg)">♫</div>
  <div class="note" style="bottom:18vh;left:16vw;font-size:9vmin;transform:rotate(7deg)">♩</div>
  <div class="note" style="bottom:32vh;right:22vw;font-size:7vmin;transform:rotate(-9deg)">♬</div>
  <div class="ring" style="width:44vmin;height:44vmin;bottom:-14vmin;right:-10vmin"></div>
  <div class="ring" style="width:30vmin;height:30vmin;top:10vh;left:-9vmin"></div>
</div></body></html>""" % (BASE_CSS, "accent" if accent else "")


def icon_html(pad_pct):
    return """<!doctype html><html><head><meta charset="utf-8"><style>
* { margin:0; box-sizing:border-box }
body { width:100vw;height:100vh;background:radial-gradient(120%% 120%% at 30%% 20%%,#FF9D3D 0%%,#FF7A00 55%%,#D95F10 100%%);
  display:flex;align-items:center;justify-content:center;overflow:hidden }
img { width:%d%%; }</style></head>
<body><img src="%s"></body></html>""" % (100 - pad_pct * 2, LOGO_URI)


# ---------------------------------------------------------------- renderer --
def render(html, w, h, out_path):
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False) as f:
        f.write(html)
        tmp = f.name
    try:
        subprocess.run(
            [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
             "--force-device-scale-factor=1", "--window-size=%d,%d" % (w, h),
             "--screenshot=" + out_path, "file://" + tmp],
            check=True, capture_output=True, timeout=120)
    finally:
        os.unlink(tmp)
    print("  %s  (%dx%d)" % (os.path.relpath(out_path, ROOT), w, h))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="render a single screen id substring")
    ap.add_argument("--sizes", default="all", choices=["phone", "tablet", "graphics", "all"])
    args = ap.parse_args()

    if not os.path.exists(CHROME):
        sys.exit("Google Chrome not found at " + CHROME)

    if args.sizes in ("phone", "tablet", "all"):
        for folder, w, h, kind in SIZES:
            if args.sizes == "phone" and kind != "phone":
                continue
            if args.sizes == "tablet" and kind == "phone":
                continue
            for s in SCREENS:
                if args.only and args.only not in s["id"]:
                    continue
                slug = s["id"] + "_" + s["headline"].lower().replace(" ", "_") \
                    .replace(".", "").replace(",", "")
                out = os.path.join(ROOT, folder, slug + ".png")
                render(page_html(s, kind, w, h), w, h, out)

    if args.sizes in ("graphics", "all") and not args.only:
        fg = os.path.join(ROOT, "play_store", "feature_graphics")
        render(feature_graphic_html(1024, 500, "feature"), 1024, 500,
               os.path.join(fg, "feature_graphic_1024x500.png"))
        render(feature_graphic_html(180, 120, "promo"), 180, 120,
               os.path.join(fg, "promo_banner_180x120.png"))
        render(feature_graphic_html(1920, 1080, "hero"), 1920, 1080,
               os.path.join(fg, "hero_image_1920x1080.png"))
        big = os.path.join(ROOT, "feature_graphics")
        render(feature_graphic_html(2560, 1440, "hero"), 2560, 1440,
               os.path.join(big, "hero_large_2560x1440.png"))
        render(background_html(False), 2560, 1440,
               os.path.join(ROOT, "backgrounds", "background_warm_2560x1440.png"))
        render(background_html(True), 2560, 1440,
               os.path.join(ROOT, "backgrounds", "background_orange_2560x1440.png"))
        render(background_html(True), 1290, 2796,
               os.path.join(ROOT, "backgrounds", "background_orange_portrait_1290x2796.png"))
        render(background_html(False), 1290, 2796,
               os.path.join(ROOT, "backgrounds", "background_warm_portrait_1290x2796.png"))
        render(icon_html(16), 1024, 1024,
               os.path.join(ROOT, "feature_graphics", "app_icon_1024_appstore.png"))
        render(icon_html(16), 512, 512,
               os.path.join(ROOT, "feature_graphics", "app_icon_512_play.png"))

    print("Done.")


if __name__ == "__main__":
    main()
