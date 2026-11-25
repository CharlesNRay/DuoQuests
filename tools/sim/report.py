"""Class report from balance-bot output (docs/BALANCE.md "Class report").

Reads .build/res_<prefix>*.txt (METRIC, STATS, RESULT, progress lines) and writes a JSON summary:
per class and path, at every 10 levels: frontier stage, game hours, win rate at the cleared frontier, fight length, and the
tested hero's damage per second, pet/minion share, damage its buffs and debuffs added for the party, healing, shields,
damage kept off by its buffs and by its own defense, damage taken, deaths per fight.

usage: py -3 tools/sim/report.py <prefix> [<prefix> ...] > out.json
"""
import glob, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))


def parse(path):
    runs = {}
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith("METRIC\t"):
            f = line.rstrip("\n").split("\t")
            cls, path_id, lv, fr, st, h, win, dur, esc, who, wcls, kv = f[1:13]
            if who != "p1":
                continue
            m = dict(x.split("=") for x in kv.split())
            m = {k: float(v) for k, v in m.items()}
            d = float(dur[3:])
            row = {
                "Level": int(lv[2:]), "Frontier": int(fr[2:]), "Hours": float(h[1:]), "Win": float(win[3:]), "Duration": d,
                "EnemyScale": float(esc[3:]),
                "DPS": m["Dealt"] / max(d, 0.5), "Dealt": m["Dealt"], "PetShare": m["PetDealt"] / max(m["Dealt"], 1),
                "Minion": m["MinionDealt"], "Dot": m["Dot"], "Enabled": m["Enabled"], "Healed": m["Healed"] + m["Lifesteal"],
                "Absorbed": m["Absorbed"], "MitByBuffs": m["MitByBuffs"], "MitDefense": m["MitDefense"], "Taken": m["Taken"],
                "Deaths": m["Deaths"], "CritRate": m["Crits"] / max(m["Hits"], 1),
            }
            runs.setdefault((cls, path_id), []).append(row)
    results = {}
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith("RESULT\t"):
            f = line.split("\t")
            cls, pp = f[1], f[2].split("+")[0]
            results.setdefault((cls, pp), []).append({"Hours": float(f[5][2:]), "Level": int(f[6][2:]), "Frontier": int(f[7][2:])})
    return runs, results


def main():
    out = {"Runs": [], "Results": []}
    for prefix in sys.argv[1:]:
        for path in sorted(glob.glob(os.path.join(HERE, ".build", "res_%s*.txt" % prefix))):
            runs, results = parse(path)
            for (cls, p), rows in runs.items():
                out["Runs"].append({"Set": prefix, "Class": cls, "Path": p, "Rows": rows})
            for (cls, p), rs in results.items():
                for r in rs:
                    out["Results"].append(dict(Set=prefix, Class=cls, Path=p, **r))
    json.dump(out, sys.stdout, indent=1)


if __name__ == "__main__":
    main()
