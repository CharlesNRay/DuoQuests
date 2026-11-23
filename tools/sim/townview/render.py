"""Headless town view: builds the plaza + town with tools/sim/townview/shim.luau and draws top-down pictures.

usage (Git Bash, from tools/sim):  py -3 townview/render.py [outdir]
Writes outdir/town_all.png, town_<district>.png and overlaps.txt (pairs of solid parts that intersect).
Needs ~/bin/luau.exe and matplotlib.
"""
import math, os, subprocess, sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, Circle

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "out")
os.makedirs(OUT, exist_ok=True)
LUAU = os.path.expanduser("~/bin/luau.exe")

def src(rel):
    return open(os.path.join(ROOT, rel), encoding="utf-8").read()

run = [src("tools/sim/townview/shim.luau")]
for name, rel in [("World", "src/shared/World.luau"), ("Errands", "src/shared/Config/Errands.luau"), ("Town", "src/client/Battle/Town.luau"), ("Hub", "src/client/Battle/Hub.luau")]:
    run.append('LOADERS["%s"] = function()\n%s\nend\n' % (name, src(rel)))
run.append('''
local Hub = require("Hub")
local noop = function() end
Hub.Build({ Map = noop, Ranks = noop, Season = noop, Daily = noop, Merchant = noop, Blacksmith = noop, Trainer = noop, PetStore = noop, RuneCarver = noop, Tree = noop, Store = noop })
Hub.SetLots({})
local World = require("World")
for _, id in ipairs(World.DistrictOrder) do
	local x, z = World.DistrictPoint(id)
	print(("D	%s	%f	%f	%f"):format(id, x, z, World.Districts[id].Size))
end
DUMP()
''')
path = os.path.join(OUT, "run.luau")
open(path, "w", encoding="utf-8").write("\n".join(run))
res = subprocess.run([LUAU, path], capture_output=True, text=True, encoding="utf-8")
if res.returncode != 0:
    print(res.stdout[-2000:], res.stderr[-4000:])
    sys.exit(1)

parts = []
for line in res.stdout.splitlines():
    if not line.startswith("P\t"):
        continue
    f = line.split("\t")
    cls, name, shape = f[1], f[2], f[3]
    n = list(map(float, f[4:23]))
    p = n[0:3]; r = n[3:6]; u = n[6:9]; b = n[9:12]; size = n[12:15]; col = n[15:18]; tr = n[18]
    text = f[23] if len(f) > 23 else ""
    parts.append(dict(cls=cls, name=name, shape=shape, p=p, r=r, u=u, b=b, size=size, col=col, tr=tr, text=text))

def corners(pt):
    # footprint on the ground (x, z) of the box, from its local axes
    sx, sy, sz = [s / 2 for s in pt["size"]]
    pts = []
    for dx, dz in [(-1, -1), (1, -1), (1, 1), (-1, 1)]:
        # project all 8 corners and take the hull via the 4 extreme combos of the two most horizontal axes
        pass
    cs = []
    for ix in (-1, 1):
        for iy in (-1, 1):
            for iz in (-1, 1):
                x = pt["p"][0] + pt["r"][0] * sx * ix + pt["u"][0] * sy * iy + pt["b"][0] * sz * iz
                z = pt["p"][2] + pt["r"][2] * sx * ix + pt["u"][2] * sy * iy + pt["b"][2] * sz * iz
                cs.append((x, z))
    # convex hull
    cs = sorted(set((round(a, 3), round(c, 3)) for a, c in cs))
    if len(cs) < 3:
        return cs
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for q in cs:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], q) <= 0:
            lower.pop()
        lower.append(q)
    for q in reversed(cs):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], q) <= 0:
            upper.pop()
        upper.append(q)
    return lower[:-1] + upper[:-1]

def top(pt):
    return pt["p"][1] + abs(pt["u"][1]) * pt["size"][1] / 2 + abs(pt["r"][1]) * pt["size"][0] / 2 + abs(pt["b"][1]) * pt["size"][2] / 2

def draw(fname, xlim, zlim, labels=True, dpi=110):
    fig, ax = plt.subplots(figsize=(14, 14 * (zlim[1] - zlim[0]) / (xlim[1] - xlim[0])))
    ax.set_facecolor((0.38, 0.63, 0.33))
    for pt in sorted(parts, key=top):
        if pt["tr"] >= 0.99 and not pt["text"]:
            continue
        cx, cz = pt["p"][0], pt["p"][2]
        if cx < xlim[0] - 60 or cx > xlim[1] + 60 or cz < zlim[0] - 60 or cz > zlim[1] + 60:
            continue
        alpha = max(0.15, 1 - pt["tr"])
        if "Cylinder" in pt["shape"] and abs(pt["r"][1]) > 0.9:
            # a flat disc (cylinder lying on its side with X up)
            ax.add_patch(Circle((cx, cz), pt["size"][1] / 2, color=pt["col"], alpha=alpha, lw=0))
        elif "Ball" in pt["shape"]:
            ax.add_patch(Circle((cx, cz), max(pt["size"][0], pt["size"][2]) / 2, color=pt["col"], alpha=alpha, lw=0))
        else:
            ax.add_patch(Polygon(corners(pt), closed=True, color=pt["col"], alpha=alpha, lw=0.3, ec=(0, 0, 0, 0.4)))
        if pt["cls"] == "WedgePart":
            # arrow: the direction the slope goes DOWN (local -Z)
            ax.annotate("", xy=(cx - pt["b"][0] * 2.5, cz - pt["b"][2] * 2.5), xytext=(cx, cz), arrowprops=dict(arrowstyle="->", color="black", lw=0.8))
        if labels and pt["text"]:
            ax.text(cx, cz, pt["text"].replace("|", "\n")[:80], fontsize=6, ha="center", va="center", color="black",
                    bbox=dict(boxstyle="round,pad=0.1", fc=(1, 1, 1, 0.6), lw=0))
            # which way the front face points (local -Z)
            ax.annotate("", xy=(cx - pt["b"][0] * 4, cz - pt["b"][2] * 4), xytext=(cx, cz), arrowprops=dict(arrowstyle="->", color="red", lw=0.8))
    ax.set_xlim(*xlim)
    ax.set_ylim(zlim[1], zlim[0])  # +Z down the page, so north (-Z) is up
    ax.set_aspect("equal")
    ax.set_xlabel("X (east ->)")
    ax.set_ylabel("Z (north is up)")
    ax.grid(True, alpha=0.2)
    fig.savefig(os.path.join(OUT, fname), dpi=dpi, bbox_inches="tight")
    plt.close(fig)

draw("town_all.png", (-330, 330), (-320, 400), labels=False, dpi=80)
draw("town_plaza.png", (-90, 90), (-40, 120))
# one close-up per district, centred on its point (World.DistrictPoint), named after the district id
import math
for line in res.stdout.splitlines():
    if line.startswith("D	"):
        _, did, dx, dz, size = line.split("	")
        dx, dz, size = float(dx), float(dz), float(size)
        draw("town_%s.png" % did.lower(), (dx - size - 15, dx + size + 15), (dz - size - 15, dz + size + 15))

# overlaps: solid parts whose footprints AND heights intersect, in different props (by name), ignoring floors
def bbox(pt):
    cs = corners(pt)
    xs = [c[0] for c in cs]; zs = [c[1] for c in cs]
    h = top(pt)
    bottom = 2 * pt["p"][1] - h
    return min(xs), max(xs), min(zs), max(zs), bottom, h
FLOOR = ("Rim", "Road", "RingRoad", "Spoke", "CrossRoad", "OpenLot", "Rug", "Ground")
solid = [pt for pt in parts if pt["tr"] < 0.9 and pt["name"] not in FLOOR and not ("Cylinder" in pt["shape"] and abs(pt["r"][1]) > 0.9 and pt["size"][0] < 1.5)]
boxes = [(pt, bbox(pt)) for pt in solid]
lines = []
for i in range(len(boxes)):
    a, A = boxes[i]
    for j in range(i + 1, len(boxes)):
        b, B = boxes[j]
        if a["name"] == b["name"]:
            continue
        if A[0] < B[1] - 0.5 and B[0] < A[1] - 0.5 and A[2] < B[3] - 0.5 and B[2] < A[3] - 0.5 and A[4] < B[5] - 0.3 and B[4] < A[5] - 0.3:
            lines.append("%s @(%.0f,%.0f)  x  %s @(%.0f,%.0f)" % (a["name"], a["p"][0], a["p"][2], b["name"], b["p"][0], b["p"][2]))
open(os.path.join(OUT, "overlaps.txt"), "w").write("\n".join(lines))
print("parts", len(parts), "overlap pairs", len(lines), "->", OUT)
