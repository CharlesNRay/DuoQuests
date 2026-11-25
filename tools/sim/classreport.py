"""Builds the class report's data files from balance-bot runs (docs/BALANCE.md "Class report").

usage: py -3 tools/sim/classreport.py <outdir> <final prefix L100> <final prefix L40> <no-talent prefix> <old L100 prefix>
Writes, each as {"rows": [...], "meta": [...]} JSON:
  progress.json   per class, path and checkpoint level (10..100): stage reached, game hours, and what the tested hero did
                  in 12 fights at its best cleared stage (per fight averages)
  talents.json    stage at level 60 with and without talents, per path
  before.json     stage at levels 40/60/80/100 before tonight's changes vs after, per path
"""
import json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glob
from report import parse, HERE

SELF = open(os.path.abspath(__file__), encoding="utf-8").read()


def load(prefix):
    runs, results = {}, {}
    for path in sorted(glob.glob(os.path.join(HERE, ".build", "res_%s_*.txt" % prefix))):
        r, res = parse(path)
        for k, v in r.items():
            runs.setdefault(k, []).extend(v)
        for k, v in res.items():
            results.setdefault(k, []).extend(v)
    return runs, results


def at_level(rows, level):
    best = None
    for r in rows:
        if r["Level"] >= level and (best is None or r["Level"] < best["Level"]):
            best = r
    return best


def main():
    outdir, final100, final40, notalent, old100 = sys.argv[1:6]
    os.makedirs(outdir, exist_ok=True)
    meta = [{"label": "classreport.py", "value": SELF, "type": "code", "lang": "python"},
            {"label": "Input", "value": "tools/sim/.build/res_%s_*.txt (balance bot, companion party, talents on)" % final100}]

    runs, results = load(final100)
    progress = []
    for (cls, path), rows in sorted(runs.items()):
        for r in sorted(rows, key=lambda r: r["Level"]):
            d = max(r["Duration"], 0.5)
            progress.append({
                "class": cls, "path": path, "level": r["Level"], "stage": r["Frontier"], "hours": round(r["Hours"], 2),
                "win_rate": round(r["Win"], 2), "fight_seconds": round(r["Duration"], 1),
                "damage_per_sec": round(r["DPS"]), "pet_share": round(r["PetShare"], 3),
                "minion_damage_per_sec": round(r["Minion"] / d), "buff_damage_per_sec": round(r["Enabled"] / d),
                "healing_per_sec": round(r["Healed"] / d), "shield_per_sec": round(r["Absorbed"] / d),
                "kept_off_by_buffs_per_sec": round(r["MitByBuffs"] / d), "kept_off_by_defense_per_sec": round(r["MitDefense"] / d),
                "taken_per_sec": round(r["Taken"] / d), "deaths_per_fight": round(r["Deaths"], 2), "crit_rate": round(r["CritRate"], 2),
            })
    json.dump({"rows": progress, "meta": meta}, open(os.path.join(outdir, "progress.json"), "w"), indent=0)

    nt_runs, _ = load(notalent)
    talents = []
    for (cls, path), rows in sorted(nt_runs.items()):
        without = at_level(rows, 60)
        with_ = at_level(runs.get((cls, path), []), 60)
        if without and with_:
            talents.append({"class": cls, "path": path, "stage_with_talents": with_["Frontier"], "stage_without_talents": without["Frontier"],
                            "hours_with": round(with_["Hours"], 1), "hours_without": round(without["Hours"], 1)})
    json.dump({"rows": talents, "meta": meta + [{"label": "No-talent input", "value": "res_%s_*.txt (to level 60)" % notalent}]},
              open(os.path.join(outdir, "talents.json"), "w"), indent=0)

    old_runs, _ = load(old100)
    before = []
    for (cls, path), rows in sorted(runs.items()):
        olds = old_runs.get((cls, path), [])
        for lv in (40, 60, 80, 90):
            a, b = at_level(olds, lv), at_level(rows, lv)
            if a and b:
                before.append({"class": cls, "path": path, "level": lv, "stage_before": a["Frontier"], "stage_after": b["Frontier"],
                               "hours_before": round(a["Hours"], 1), "hours_after": round(b["Hours"], 1),
                               "fight_seconds_before": round(a["Duration"], 1), "fight_seconds_after": round(b["Duration"], 1)})
    json.dump({"rows": before, "meta": meta + [{"label": "Before input", "value": "res_%s_*.txt (before fight length, after the late-game fix)" % old100}]},
              open(os.path.join(outdir, "before.json"), "w"), indent=0)
    print(len(progress), len(talents), len(before))


if __name__ == "__main__":
    main()
