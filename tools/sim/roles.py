"""Role check: what share of the party's damage, healing and damage taken the tested hero has, per path and level band.

usage: py -3 tools/sim/roles.py <prefix>     reads .build/res_<prefix>_*.txt (METRIC lines from balance90.luau)
Shares do not depend on the stage a path reached, so paths compare fairly:
  a tank should take the most, a healer should do most of the healing, a damage path most of the damage.
"""
import glob, os, re, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
prefix = sys.argv[1]
BANDS = [(30, 50, "L30-50"), (51, 75, "L51-75"), (76, 200, "L76+")]

acc = defaultdict(lambda: defaultdict(float))
for path in sorted(glob.glob(os.path.join(HERE, ".build", "res_%s_*.txt" % prefix))):
    fights = defaultdict(dict)
    for line in open(path, encoding="utf-8", errors="replace"):
        if not line.startswith("METRIC"):
            continue
        parts = line.rstrip("\n").split("\t")
        cls, sub, lv, fr, st = parts[1], parts[2], int(parts[3][2:]), parts[4], parts[5]
        who = parts[10]
        vals = dict(kv.split("=") for kv in parts[12].split())
        vals = {k: float(v) for k, v in vals.items()}
        fights[(sub, lv, fr, st, parts[6])][who] = vals
    for (sub, lv, fr, st, h), members in fights.items():
        band = next((b[2] for b in BANDS if b[0] <= lv <= b[1]), None)
        if not band or "p1" not in members:
            continue
        def dmg(v):
            return v["Dealt"] + v.get("MinionDealt", 0)
        def heal(v):
            return v["Healed"] + v["Absorbed"] + v["Lifesteal"]
        tot = {k: sum(f(v) for v in members.values()) for k, f in (("dmg", dmg), ("heal", heal), ("taken", lambda v: v["Taken"]))}
        me = members["p1"]
        a = acc[(sub, band)]
        a["n"] += 1
        a["dmg"] += dmg(me) / max(tot["dmg"], 1)
        a["heal"] += heal(me) / max(tot["heal"], 1)
        a["self"] += me["Lifesteal"] / max(heal(me), 1)
        a["taken"] += me["Taken"] / max(tot["taken"], 1)
        a["deaths"] += me["Deaths"]

subs = sorted({k[0] for k in acc})
print("%-13s %-7s %4s %6s %6s %6s %6s %6s" % ("path", "band", "n", "dmg%", "heal%", "ls%", "taken%", "deaths"))
for s in subs:
    for _, _, band in BANDS:
        a = acc.get((s, band))
        if not a:
            continue
        n = a["n"]
        print("%-13s %-7s %4d %6.0f %6.0f %6.0f %6.0f %6.2f" % (s, band, n, 100 * a["dmg"] / n, 100 * a["heal"] / n, 100 * a["self"] / n, 100 * a["taken"] / n, a["deaths"] / n))
