"""Draws the Idle Party Quest icon (1024 + 512) and thumbnail (1920x1080) as SVG, then renders PNGs with headless Chrome.

  py -3 branding/make_art.py
"""
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
INK = "#0b0c1c"
FONT = "Arial Black, Impact, sans-serif"

GOLD = """<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff3b0"/><stop offset="0.55" stop-color="#ffc93c"/><stop offset="1" stop-color="#f29a00"/></linearGradient>"""

SHIELD = "M512 150 L790 230 C790 470 720 650 512 780 C304 650 234 470 234 230 Z"


def title(x, y, text, size, spacing=4, stroke=None):
    stroke = stroke or size * 0.16
    common = f'x="{x}" y="{y}" text-anchor="middle" font-family="{FONT}" font-weight="900" font-size="{size}" letter-spacing="{spacing}"'
    return (
        f'<text {common} fill="{INK}" stroke="{INK}" stroke-width="{stroke * 1.6}" stroke-linejoin="round" transform="translate(0 {size * 0.05})">{text}</text>'
        f'<text {common} fill="{INK}" stroke="{INK}" stroke-width="{stroke}" stroke-linejoin="round">{text}</text>'
        f'<text {common} fill="url(#gold)">{text}</text>'
    )


def emblem():
    """The quartered shield (one colour per hero class) with a crossed sword and staff, in 1024 icon space."""
    quarters = [
        (200, 120, "#ff7a45", "#d63a2a"),  # Warrior
        (512, 120, "#7aa8ff", "#3b5fe0"),  # Mage
        (200, 445, "#7ee08a", "#2f9e57"),  # Ranger
        (512, 445, "#fff1b8", "#f0b93a"),  # Cleric
    ]
    defs = ""
    rects = ""
    for i, (x, y, a, b) in enumerate(quarters):
        defs += f'<linearGradient id="q{i}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{a}"/><stop offset="1" stop-color="{b}"/></linearGradient>'
        rects += f'<rect x="{x}" y="{y}" width="312" height="325" fill="url(#q{i})"/>'
    body = f"""
  <defs>{defs}<clipPath id="shieldClip"><path d="{SHIELD}"/></clipPath>
    <radialGradient id="orb" cx="0.4" cy="0.35" r="0.7"><stop offset="0" stop-color="#ffffff"/><stop offset="0.35" stop-color="#b9f3ff"/><stop offset="1" stop-color="#3aa0ff"/></radialGradient>
    <radialGradient id="orbGlow"><stop offset="0" stop-color="#9fe8ff" stop-opacity="0.9"/><stop offset="1" stop-color="#9fe8ff" stop-opacity="0"/></radialGradient>
  </defs>
  <path d="{SHIELD}" fill="#1b1d3a" stroke="{INK}" stroke-width="26" stroke-linejoin="round"/>
  <g clip-path="url(#shieldClip)">{rects}
    <path d="M512 120 V820 M200 445 H824" stroke="{INK}" stroke-width="12"/>
    <path d="M300 200 Q512 150 724 200 L700 260 Q512 215 324 260 Z" fill="#ffffff" opacity="0.18"/>
  </g>
  <path d="{SHIELD}" fill="none" stroke="url(#gold)" stroke-width="18" stroke-linejoin="round"/>
  <g stroke="{INK}" stroke-width="9" stroke-linejoin="round">
    <g transform="rotate(40 512 440)">
      <path d="M512 175 L540 240 V560 H484 V240 Z" fill="#f4f6ff"/>
      <path d="M512 200 L524 240 V545 H512 Z" fill="#c9d2f5" stroke="none"/>
      <rect x="436" y="560" width="152" height="30" rx="10" fill="url(#gold)"/>
      <rect x="496" y="590" width="32" height="86" rx="9" fill="#6b3a1e"/>
      <circle cx="512" cy="694" r="22" fill="url(#gold)"/>
    </g>
    <g transform="rotate(-40 512 440)">
      <rect x="496" y="230" width="32" height="470" rx="12" fill="#8a5a2b"/>
      <path d="M470 250 Q512 150 554 250 Q512 225 470 250 Z" fill="url(#gold)"/>
    </g>
  </g>
  <circle cx="358" cy="262" r="92" fill="url(#orbGlow)"/>
  <circle cx="358" cy="262" r="44" fill="url(#orb)" stroke="{INK}" stroke-width="9"/>
  <path d="M342 246 a14 14 0 0 1 16 -8" stroke="#fff" stroke-width="7" fill="none" stroke-linecap="round"/>
"""
    return body


def sparkle(x, y, r, color="#fff6c8", opacity=1.0):
    return f'<path d="M{x} {y - r} Q{x + r * 0.18} {y - r * 0.18} {x + r} {y} Q{x + r * 0.18} {y + r * 0.18} {x} {y + r} Q{x - r * 0.18} {y + r * 0.18} {x - r} {y} Q{x - r * 0.18} {y - r * 0.18} {x} {y - r} Z" fill="{color}" opacity="{opacity}"/>'


def icon():
    stars = "".join(sparkle(x, y, r, opacity=o) for x, y, r, o in [
        (120, 140, 22, 0.9), (900, 120, 28, 0.95), (170, 520, 14, 0.6), (880, 470, 16, 0.7), (80, 330, 10, 0.5), (950, 300, 11, 0.5)])
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>{GOLD}
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4a2f9a"/><stop offset="0.6" stop-color="#241d5c"/><stop offset="1" stop-color="#120f2e"/></linearGradient>
    <radialGradient id="glow" cx="0.5" cy="0.36" r="0.5"><stop offset="0" stop-color="#ffd76a" stop-opacity="0.55"/><stop offset="0.5" stop-color="#b06cff" stop-opacity="0.2"/><stop offset="1" stop-color="#b06cff" stop-opacity="0"/></radialGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#bg)"/>
  <rect width="1024" height="1024" fill="url(#glow)"/>
  <g opacity="0.16" stroke="#ffe9a0" stroke-width="30">{''.join(f'<path d="M512 380 L{512 + 900 * c} {380 + 900 * s}"/>' for c, s in [(1, 0), (0.7, 0.7), (0, 1), (-0.7, 0.7), (-1, 0), (-0.7, -0.7), (0, -1), (0.7, -0.7)])}</g>
  {stars}
  <g transform="translate(512 40) scale(0.84) translate(-512 -150)">{emblem()}</g>
  {title(512, 790, "IDLE PARTY", 132, 4)}
  {title(512, 962, "QUEST", 196, 14)}
</svg>"""


# ---- thumbnail -------------------------------------------------------------------------------------------------------

SKIN = "#f7cf3e"


def hero(x, ground, s, kind, face="smile"):
    """A chunky block hero facing right. kind: Warrior / Mage / Ranger / Cleric."""
    look = {
        "Warrior": ("#c8352b", "#8c2219", "#4a4f63"),
        "Mage": ("#3b5fe0", "#25389a", "#2b2350"),
        "Ranger": ("#2f9e57", "#1f6b3a", "#5a3b22"),
        "Cleric": ("#f4f1e4", "#d9b44a", "#6a6a8a"),
    }[kind]
    body, trim, legs = look
    sw = 7
    parts = []
    a = parts.append
    # legs
    a(f'<rect x="-30" y="-62" width="26" height="62" rx="5" fill="{legs}"/>')
    a(f'<rect x="4" y="-62" width="26" height="62" rx="5" fill="{legs}"/>')
    # back arm
    a(f'<rect x="-52" y="-132" width="24" height="64" rx="8" fill="{trim}"/>')
    # torso
    if kind in ("Mage", "Cleric"):
        a(f'<path d="M-36 -136 H36 L44 -50 H-44 Z" fill="{body}"/>')
        a(f'<path d="M-6 -136 H6 V-50 H-6 Z" fill="{trim}" stroke="none"/>')
    else:
        a(f'<rect x="-36" y="-136" width="72" height="80" rx="8" fill="{body}"/>')
        a(f'<rect x="-36" y="-80" width="72" height="14" fill="{trim}"/>')
    # head
    a(f'<rect x="-30" y="-196" width="60" height="58" rx="12" fill="{SKIN}"/>')
    if face == "shock":
        a(f'<circle cx="6" cy="-162" r="9" fill="#fff" stroke-width="4"/><circle cx="24" cy="-162" r="9" fill="#fff" stroke-width="4"/>')
        a(f'<circle cx="8" cy="-161" r="4" fill="{INK}" stroke="none"/><circle cx="26" cy="-161" r="4" fill="{INK}" stroke="none"/>')
        a(f'<ellipse cx="16" cy="-146" rx="7" ry="7" fill="#5a1010" stroke-width="4"/>')
    else:
        a(f'<rect x="4" y="-176" width="8" height="12" rx="2" fill="{INK}" stroke="none"/><rect x="18" y="-176" width="8" height="12" rx="2" fill="{INK}" stroke="none"/>')
        a(f'<path d="M6 -156 Q16 -149 26 -156" fill="none" stroke="{INK}" stroke-width="4" stroke-linecap="round"/>')
    # headgear
    if kind == "Warrior":
        a(f'<path d="M-36 -176 Q-36 -214 0 -214 Q36 -214 36 -176 L36 -170 H-36 Z" fill="#b9c0d8"/>')
        a(f'<path d="M-6 -214 Q-4 -246 14 -252 Q8 -232 10 -214 Z" fill="#e2412f"/>')
    elif kind == "Mage":
        a(f'<path d="M-44 -186 H44 L10 -278 Q2 -284 -2 -270 Z" fill="#25389a"/>')
        a(f'<rect x="-44" y="-194" width="88" height="14" rx="6" fill="url(#gold)"/>')
    elif kind == "Ranger":
        a(f'<path d="M-38 -150 Q-44 -224 2 -222 Q40 -220 36 -186 L36 -176 L-6 -190 L-24 -146 Z" fill="#1f6b3a"/>')
    else:
        a(f'<ellipse cx="0" cy="-222" rx="34" ry="9" fill="none" stroke="#ffe680" stroke-width="7"/>')
    # front arm + weapon
    if kind == "Warrior":
        a(f'<g transform="rotate(30 40 -110)"><path d="M40 -330 L54 -300 V-140 H26 V-300 Z" fill="#f4f6ff"/><rect x="12" y="-142" width="56" height="14" rx="5" fill="url(#gold)"/><rect x="33" y="-128" width="14" height="34" rx="4" fill="#6b3a1e"/></g>')
        a(f'<rect x="28" y="-132" width="24" height="60" rx="8" fill="{trim}"/>')
        a(f'<path d="M-70 -128 H-24 V-76 Q-24 -46 -47 -36 Q-70 -46 -70 -76 Z" fill="#b9c0d8"/><path d="M-47 -118 V-48 M-62 -96 H-32" stroke="#e2412f" stroke-width="8"/>')
    elif kind == "Mage":
        a(f'<rect x="28" y="-132" width="24" height="60" rx="8" fill="{trim}"/>')
        a(f'<rect x="52" y="-250" width="14" height="250" rx="6" fill="#8a5a2b"/>')
        a(f'<circle cx="59" cy="-266" r="50" fill="url(#orbGlowT)" stroke="none"/><circle cx="59" cy="-266" r="22" fill="url(#orbT)"/>')
    elif kind == "Ranger":
        a(f'<path d="M70 -250 Q140 -130 70 -10" fill="none" stroke="#8a5a2b" stroke-width="14" stroke-linecap="round"/>')
        a(f'<path d="M70 -250 L70 -10" stroke="#e8e2c8" stroke-width="3"/>')
        a(f'<path d="M20 -128 H150 M150 -128 l-18 -10 v20 Z" stroke="#e8e2c8" stroke-width="5" fill="#e8e2c8"/>')
        a(f'<rect x="28" y="-138" width="56" height="22" rx="8" fill="{trim}"/>')
    else:
        a(f'<rect x="28" y="-132" width="24" height="60" rx="8" fill="{trim}"/>')
        a(f'<rect x="52" y="-236" width="14" height="236" rx="6" fill="#d9d2b6"/>')
        a(f'<circle cx="59" cy="-250" r="56" fill="url(#holyGlow)" stroke="none"/>')
        a(f'<path d="M59 -282 V-218 M35 -258 H83" stroke="url(#gold)" stroke-width="12" stroke-linecap="round"/>')
    inner = "".join(parts)
    return f'<g transform="translate({x} {ground}) scale({s})" stroke="{INK}" stroke-width="{sw}" stroke-linejoin="round">{inner}</g>'


def slime(cx, ground, r):
    h = r * 1.55
    body = f'M{cx - r} {ground} Q{cx - r * 1.08} {ground - h * 0.55} {cx - r * 0.55} {ground - h * 0.9} Q{cx} {ground - h * 1.12} {cx + r * 0.55} {ground - h * 0.9} Q{cx + r * 1.08} {ground - h * 0.55} {cx + r} {ground} Z'
    eye = lambda ex: f'<ellipse cx="{ex}" cy="{ground - h * 0.52}" rx="{r * 0.1}" ry="{r * 0.16}" fill="{INK}"/><circle cx="{ex + r * 0.03}" cy="{ground - h * 0.57}" r="{r * 0.035}" fill="#fff"/>'
    crown_y = ground - h * 1.02
    crown = f'M{cx - r * 0.34} {crown_y} L{cx - r * 0.4} {crown_y - r * 0.38} L{cx - r * 0.18} {crown_y - r * 0.18} L{cx} {crown_y - r * 0.46} L{cx + r * 0.18} {crown_y - r * 0.18} L{cx + r * 0.4} {crown_y - r * 0.38} L{cx + r * 0.34} {crown_y} Z'
    return f"""
  <ellipse cx="{cx}" cy="{ground + 6}" rx="{r * 1.05}" ry="{r * 0.12}" fill="#000" opacity="0.3"/>
  <path d="{body}" fill="url(#rainbow)" stroke="{INK}" stroke-width="10" stroke-linejoin="round"/>
  <path d="{body}" fill="url(#slimeShade)"/>
  <ellipse cx="{cx - r * 0.42}" cy="{ground - h * 0.78}" rx="{r * 0.16}" ry="{r * 0.09}" fill="#fff" opacity="0.75" transform="rotate(-30 {cx - r * 0.42} {ground - h * 0.78})"/>
  {eye(cx - r * 0.42)}{eye(cx - r * 0.08)}
  <path d="M{cx - r * 0.4} {ground - h * 0.3} Q{cx - r * 0.25} {ground - h * 0.2} {cx - r * 0.1} {ground - h * 0.3}" fill="none" stroke="{INK}" stroke-width="9" stroke-linecap="round"/>
  <path d="{crown}" fill="url(#gold)" stroke="{INK}" stroke-width="9" stroke-linejoin="round"/>
  <circle cx="{cx}" cy="{crown_y - r * 0.1}" r="{r * 0.06}" fill="#ff4f8b" stroke="{INK}" stroke-width="5"/>
"""


def pop(x, y, text, size, color, rot=0):
    return f'<g transform="rotate({rot} {x} {y})"><text x="{x}" y="{y}" text-anchor="middle" font-family="{FONT}" font-size="{size}" fill="{INK}" stroke="{INK}" stroke-width="{size * 0.22}" stroke-linejoin="round">{text}</text><text x="{x}" y="{y}" text-anchor="middle" font-family="{FONT}" font-size="{size}" fill="{color}">{text}</text></g>'


def thumbnail():
    W, H, G = 1920, 1080, 930
    stars = "".join(sparkle(x, y, r, opacity=o) for x, y, r, o in [
        (140, 120, 18, 0.8), (1780, 140, 22, 0.85), (1500, 90, 12, 0.6), (420, 80, 10, 0.5), (1650, 380, 9, 0.5), (90, 420, 9, 0.4)])
    mountains_far = f'<path d="M0 700 L180 520 L320 640 L520 430 L700 610 L880 500 L1060 640 L1260 450 L1460 620 L1640 480 L1920 660 V{H} H0 Z" fill="#3a2f7a"/>'
    caps = '<path d="M520 430 L470 482 L500 476 L530 494 L560 470 Z M1260 450 L1214 500 L1246 492 L1272 508 L1300 488 Z M1640 480 L1600 520 L1628 514 L1652 528 L1676 510 Z" fill="#cfd4ff" opacity="0.8"/>'
    mountains_near = f'<path d="M0 800 Q200 690 380 760 Q560 820 760 730 Q980 640 1180 750 Q1400 850 1600 720 Q1760 640 1920 720 V{H} H0 Z" fill="#2a2360"/>'
    castle = '<g fill="#221c4e"><rect x="1040" y="560" width="160" height="200"/><rect x="1010" y="520" width="50" height="240"/><rect x="1180" y="520" width="50" height="240"/><path d="M1005 520 L1035 470 L1065 520 Z M1175 520 L1205 470 L1235 520 Z"/><rect x="1095" y="500" width="50" height="80"/><path d="M1090 500 L1120 440 L1150 500 Z"/></g>'
    ground = f'<path d="M0 {G - 20} Q480 {G - 60} 960 {G - 25} Q1440 {G + 10} 1920 {G - 40} V{H} H0 Z" fill="url(#grass)" stroke="{INK}" stroke-width="8"/>'
    heroes = hero(200, G, 1.25, "Cleric") + hero(480, G - 6, 1.25, "Mage") + hero(770, G - 14, 1.35, "Ranger") + hero(1110, G - 18, 1.45, "Warrior")
    shadows = "".join(f'<ellipse cx="{x}" cy="{G + 2 - d}" rx="70" ry="14" fill="#000" opacity="0.25"/>' for x, d in [(200, 0), (480, 6), (770, 14), (1110, 18)])
    fx = (
        sparkle(1440, 700, 64, "#fff3b0") + sparkle(1410, 800, 30, "#ffffff", 0.9)
        + pop(1330, 470, "CRIT!", 64, "#ff9a2e", -8) + pop(1360, 560, "128.4K", 88, "#fff3b0", -8)
        + pop(620, 540, "+42K", 46, "#7ee08a", 6)
    )
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">
  <defs>{GOLD}
    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3d2a8f"/><stop offset="0.55" stop-color="#8a4fc4"/><stop offset="1" stop-color="#ff9f7a"/></linearGradient>
    <linearGradient id="grass" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5fd06a"/><stop offset="1" stop-color="#2c8a46"/></linearGradient>
    <linearGradient id="rainbow" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ff5f7e"/><stop offset="0.25" stop-color="#ffb347"/><stop offset="0.45" stop-color="#ffe66b"/><stop offset="0.65" stop-color="#6fe39a"/><stop offset="0.82" stop-color="#5fb8ff"/><stop offset="1" stop-color="#b77bff"/></linearGradient>
    <radialGradient id="slimeShade" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#fff" stop-opacity="0.25"/><stop offset="0.6" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.25"/></radialGradient>
    <radialGradient id="orbT" cx="0.4" cy="0.35" r="0.7"><stop offset="0" stop-color="#ffffff"/><stop offset="0.35" stop-color="#b9f3ff"/><stop offset="1" stop-color="#3aa0ff"/></radialGradient>
    <radialGradient id="orbGlowT"><stop offset="0" stop-color="#9fe8ff" stop-opacity="0.9"/><stop offset="1" stop-color="#9fe8ff" stop-opacity="0"/></radialGradient>
    <radialGradient id="holyGlow"><stop offset="0" stop-color="#fff3b0" stop-opacity="0.9"/><stop offset="1" stop-color="#fff3b0" stop-opacity="0"/></radialGradient>
    <radialGradient id="sun" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#fff3c4" stop-opacity="0.9"/><stop offset="1" stop-color="#ffb070" stop-opacity="0"/></radialGradient>
  </defs>
  <rect width="{W}" height="{H}" fill="url(#sky)"/>
  <circle cx="1500" cy="620" r="420" fill="url(#sun)"/>
  {stars}
  {mountains_far}{caps}{castle}{mountains_near}
  {ground}
  {shadows}
  {slime(1650, G - 30, 205)}
  {heroes}
  {fx}
  {title(960, 190, "IDLE PARTY QUEST", 150, 6)}
  <g><rect x="400" y="236" width="1120" height="64" rx="32" fill="{INK}" opacity="0.55"/>
  <text x="960" y="281" text-anchor="middle" font-family="{FONT}" font-size="34" letter-spacing="3" fill="#ffffff">TEAM UP · AUTO-BATTLE · HUNDREDS OF STAGES</text></g>
</svg>"""


# ---- louder "hype" variants (bright burst, giant boss, shocked heroes, arrows) -----------------------------------------

HYPE_DEFS = """
    <radialGradient id="burstBg" cx="0.5" cy="0.5" r="0.75"><stop offset="0" stop-color="#fff6a0"/><stop offset="0.35" stop-color="#ffb020"/><stop offset="0.75" stop-color="#ff4d2e"/><stop offset="1" stop-color="#8a0f3c"/></radialGradient>
    <linearGradient id="red" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff5a4a"/><stop offset="1" stop-color="#c4121f"/></linearGradient>
    <linearGradient id="white" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#dfe6ff"/></linearGradient>
"""


def rays(cx, cy, n, length, color, opacity):
    import math
    out = []
    for i in range(n):
        a0 = (i / n) * 2 * math.pi
        a1 = a0 + math.pi / n
        out.append(f'M{cx} {cy} L{cx + length * math.cos(a0):.0f} {cy + length * math.sin(a0):.0f} L{cx + length * math.cos(a1):.0f} {cy + length * math.sin(a1):.0f} Z')
    return f'<path d="{" ".join(out)}" fill="{color}" opacity="{opacity}"/>'


def starburst(cx, cy, r, points, fill):
    import math
    pts = []
    for i in range(points * 2):
        rr = r if i % 2 == 0 else r * 0.74
        a = i * math.pi / points - math.pi / 2
        pts.append(f"{cx + rr * math.cos(a):.0f},{cy + rr * math.sin(a):.0f}")
    return f'<polygon points="{" ".join(pts)}" fill="{fill}" stroke="{INK}" stroke-width="10" stroke-linejoin="round"/>'


def shout(x, y, text, size, fill="url(#white)", rot=0, spacing=2):
    common = f'x="{x}" y="{y}" text-anchor="middle" font-family="{FONT}" font-size="{size}" letter-spacing="{spacing}"'
    return (f'<g transform="rotate({rot} {x} {y})">'
            f'<text {common} fill="{INK}" stroke="{INK}" stroke-width="{size * 0.3}" stroke-linejoin="round" transform="translate(0 {size * 0.07})">{text}</text>'
            f'<text {common} fill="{INK}" stroke="{INK}" stroke-width="{size * 0.2}" stroke-linejoin="round">{text}</text>'
            f'<text {common} fill="{fill}">{text}</text></g>')


def arrow(x1, y1, x2, y2, width=34):
    import math
    ang = math.degrees(math.atan2(y2 - y1, x2 - x1))
    length = math.hypot(x2 - x1, y2 - y1)
    head = width * 2.4
    shaft = length - head
    path = (f'M0 {-width / 2} L{shaft} {-width / 2} L{shaft} {-width * 1.3} L{length} 0 L{shaft} {width * 1.3} '
            f'L{shaft} {width / 2} L0 {width / 2} Z')
    return f'<path d="{path}" fill="url(#red)" stroke="{INK}" stroke-width="10" stroke-linejoin="round" transform="translate({x1} {y1}) rotate({ang:.1f})"/>'


def thumbnail_hype():
    W, H, G = 1920, 1080, 1010
    heroes = (hero(170, G, 1.35, "Cleric", "shock") + hero(430, G - 4, 1.4, "Mage", "shock")
              + hero(700, G - 8, 1.5, "Ranger", "shock") + hero(980, G - 10, 1.65, "Warrior", "shock"))
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">
  <defs>{GOLD}{HYPE_DEFS}
    <linearGradient id="rainbow" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ff5f7e"/><stop offset="0.25" stop-color="#ffb347"/><stop offset="0.45" stop-color="#ffe66b"/><stop offset="0.65" stop-color="#6fe39a"/><stop offset="0.82" stop-color="#5fb8ff"/><stop offset="1" stop-color="#b77bff"/></linearGradient>
    <radialGradient id="slimeShade" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#fff" stop-opacity="0.25"/><stop offset="0.6" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.25"/></radialGradient>
    <radialGradient id="orbT" cx="0.4" cy="0.35" r="0.7"><stop offset="0" stop-color="#ffffff"/><stop offset="0.35" stop-color="#b9f3ff"/><stop offset="1" stop-color="#3aa0ff"/></radialGradient>
    <radialGradient id="orbGlowT"><stop offset="0" stop-color="#9fe8ff" stop-opacity="0.9"/><stop offset="1" stop-color="#9fe8ff" stop-opacity="0"/></radialGradient>
    <radialGradient id="holyGlow"><stop offset="0" stop-color="#fff3b0" stop-opacity="0.9"/><stop offset="1" stop-color="#fff3b0" stop-opacity="0"/></radialGradient>
  </defs>
  <rect width="{W}" height="{H}" fill="url(#burstBg)"/>
  {rays(1450, 560, 22, 1800, "#fff3a0", 0.28)}
  <path d="M0 {G - 10} Q960 {G - 50} 1920 {G - 20} V{H} H0 Z" fill="#3cba5c" stroke="{INK}" stroke-width="8"/>
  {slime(1480, G - 20, 380)}
  <circle cx="1480" cy="310" r="165" fill="none" stroke="#ff2a2a" stroke-width="16"/>
  {heroes}
  {arrow(1060, 420, 1290, 350)}
  {starburst(1700, 190, 150, 14, "url(#red)")}
  {shout(1700, 200, "100s", 80, "url(#gold)", rot=-10)}
  {shout(1700, 258, "OF STAGES!", 36, rot=-10)}
  {shout(560, 150, "GO AFK...", 120, "url(#white)", rot=-4)}
  {shout(600, 300, "GET OP!!", 150, "url(#gold)", rot=-4)}
  {pop(1600, 900, "999.9M", 70, "#fff3b0", -6)}
  {shout(1610, 1052, "IDLE PARTY QUEST", 44, "url(#gold)")}
</svg>"""


def icon_hype():
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>{GOLD}{HYPE_DEFS}
    <linearGradient id="rainbow" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ff5f7e"/><stop offset="0.25" stop-color="#ffb347"/><stop offset="0.45" stop-color="#ffe66b"/><stop offset="0.65" stop-color="#6fe39a"/><stop offset="0.82" stop-color="#5fb8ff"/><stop offset="1" stop-color="#b77bff"/></linearGradient>
    <radialGradient id="slimeShade" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#fff" stop-opacity="0.25"/><stop offset="0.6" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.25"/></radialGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#burstBg)"/>
  {rays(620, 420, 18, 1200, "#fff3a0", 0.3)}
  {slime(650, 900, 300)}
  {hero(250, 1080, 2.6, "Warrior", "shock")}
  {starburst(830, 160, 130, 12, "url(#red)")}
  {shout(830, 150, "AFK", 70, rot=-10)}
  {shout(830, 220, "= OP", 56, "url(#gold)", rot=-10)}
  {shout(512, 990, "IDLE PARTY QUEST", 92, "url(#gold)")}
</svg>"""


def render(svg_text, name, w, h, extra_sizes=()):
    svg_path = os.path.join(HERE, name + ".svg")
    with open(svg_path, "w", encoding="utf-8") as f:
        f.write(svg_text)
    png = os.path.join(HERE, name + ".png")
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--default-background-color=00000000",
                    f"--window-size={w},{h}", f"--screenshot={png}", "file:///" + svg_path.replace("\\", "/")],
                   check=True, capture_output=True)
    from PIL import Image
    img = Image.open(png).convert("RGB").crop((0, 0, w, h))
    img.save(png)
    for size in extra_sizes:
        img.resize((size, size), Image.LANCZOS).save(os.path.join(HERE, f"{name}_{size}.png"))
    print("wrote", png)


if __name__ == "__main__":
    render(icon(), "icon", 1024, 1024, extra_sizes=(512, 150))
    render(thumbnail(), "thumbnail", 1920, 1080)
    render(icon_hype(), "icon_hype", 1024, 1024, extra_sizes=(512,))
    render(thumbnail_hype(), "thumbnail_hype", 1920, 1080)
