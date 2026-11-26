"""Every icon glyph in the game, in one place.

Writes src/shared/Config/IconLooks.luau and checks that:
  - no glyph is used twice (skills, path skills, statuses, ultimates, pet skills, passives, talents, runes, consumables),
  - every glyph is an emoji from Unicode emoji 12.0 or older (Roblox does not draw newer ones; see CLAUDE.md).
Talents, runes and consumables keep their Glyph in their own Config files; this script reads them to check them.

usage: py -3 tools/icons/icons.py [emoji-test.txt]
emoji-test.txt: https://unicode.org/Public/emoji/15.1/emoji-test.txt (versions per emoji). Without it only duplicates are checked.
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# id: (glyph, (r, g, b))
SKILLS = {
    # Warrior
    "ShieldBash": ("🔨", (170, 120, 60)), "Taunt": ("📣", (150, 80, 60)), "IronSkin": ("🔩", (110, 120, 140)),
    "Whirlwind": ("🌀", (70, 150, 170)), "ShieldWall": ("🧱", (60, 100, 180)), "CrushingBlow": ("💢", (160, 60, 50)),
    "LastStand": ("💪", (190, 90, 50)), "RallyingCry": ("🚩", (200, 150, 50)),
    "BloodFrenzy": ("👹", (170, 30, 50)), "Cleave": ("🪓", (190, 90, 80)), "ExecutionerStrike": ("☠", (110, 40, 60)),
    "Bulwark": ("🏰", (90, 110, 150)), "Retribution": ("🔁", (210, 120, 60)), "UnbreakableVow": ("💍", (180, 170, 130)),
    "WarlordsRoar": ("🦁", (220, 140, 50)), "AegisOfAges": ("🏛", (150, 160, 190)),
    # Cleric
    "Smite": ("⚡", (230, 200, 90)), "Heal": ("➕", (60, 170, 100)), "Blessing": ("🙏", (220, 190, 120)),
    "Purify": ("🧼", (150, 220, 240)), "RadiantBurst": ("☀", (240, 210, 110)), "DivineShield": ("🔰", (110, 170, 230)),
    "GroupHeal": ("💞", (90, 190, 130)), "GuardianAngel": ("👼", (200, 210, 240)), "Judgment": ("⚖", (220, 180, 70)),
    "Resurrection": ("🕊", (170, 230, 190)),
    "Sanctuary": ("⛪", (120, 200, 190)), "Renewal": ("🌿", (120, 200, 120)), "HolyAegis": ("✝", (150, 190, 240)),
    "HolyWrath": ("✴", (240, 170, 60)), "Verdict": ("📜", (235, 200, 110)), "DivineSmite": ("🌟", (250, 230, 150)),
    "Resurgence": ("🌄", (250, 190, 120)), "HolyCrusade": ("🛐", (240, 220, 160)),
    # Mage
    "Fireball": ("🔥", (220, 90, 40)), "Blizzard": ("❄", (100, 180, 230)), "LightningBolt": ("🌩", (230, 220, 70)),
    "ArcaneSurge": ("🔮", (150, 90, 210)), "ArcaneBlast": ("💠", (120, 110, 230)), "ChainLightning": ("🔗", (200, 210, 90)),
    "ManaShield": ("🌐", (80, 140, 230)), "Meteor": ("☄", (200, 100, 60)),
    "Ignite": ("🌶", (230, 70, 40)), "Inferno": ("🌋", (190, 60, 30)), "PhoenixFire": ("🦅", (240, 130, 40)),
    "DeepFreeze": ("🌬", (150, 210, 240)), "FrostArmor": ("⛄", (170, 210, 240)), "Glacier": ("🏔", (120, 170, 210)),
    "Cataclysm": ("☢", (220, 120, 40)), "AbsoluteZero": ("🌨", (190, 230, 255)),
    # Ranger
    "PowerShot": ("🏹", (140, 110, 70)), "Volley": ("🎇", (200, 160, 80)), "PiercingArrow": ("📌", (190, 70, 70)),
    "Snare": ("🕸", (150, 140, 120)), "Evasion": ("🍃", (110, 190, 110)), "HuntersMark": ("🎯", (220, 80, 70)),
    "RapidFire": ("⏩", (210, 150, 60)), "ExplosiveArrow": ("🧨", (220, 90, 60)),
    "DeadEye": ("👁", (240, 190, 80)), "Headshot": ("🔭", (170, 120, 90)), "Barrage": ("🎆", (210, 120, 80)),
    "PackHowl": ("🐺", (120, 130, 140)), "Stampede": ("🐗", (140, 100, 70)), "NaturesBond": ("🌳", (80, 150, 80)),
    "RainOfArrows": ("☔", (110, 140, 190)), "PrimalSurge": ("🦍", (110, 90, 70)),
    # Rogue
    "Backstab": ("🗡", (120, 120, 140)), "FanOfKnives": ("🔪", (170, 170, 190)), "PoisonBlade": ("🐍", (100, 180, 80)),
    "Smokescreen": ("🌫", (140, 140, 150)), "Shadowstep": ("👣", (80, 70, 110)), "Eviscerate": ("✂", (190, 60, 70)),
    "Flurry": ("🌪", (150, 170, 190)), "Vanish": ("🎩", (60, 60, 80)),
    "DeathMark": ("🃏", (130, 50, 70)), "Execute": ("⚰", (90, 60, 70)), "ShadowStrike": ("🌘", (90, 80, 140)),
    "Riposte": ("🤺", (180, 180, 200)), "Parry": ("🛡", (130, 150, 180)), "BladeDance": ("💃", (210, 90, 130)),
    "VanishingStrike": ("🦇", (70, 60, 100)), "ThousandCuts": ("🌸", (240, 160, 190)),
    # Summoner
    "SummonImp": ("👿", (170, 60, 140)), "WraithSwarm": ("👻", (170, 180, 220)), "SoulLeech": ("🧛", (140, 40, 70)),
    "RaiseSkeleton": ("💀", (200, 200, 190)), "Haunt": ("🏚", (100, 90, 120)), "Devour": ("👄", (200, 70, 90)),
    "BoneArmor": ("🦴", (220, 210, 180)), "CallTitan": ("🗿", (130, 130, 140)),
    "RaiseDead": ("🧟", (100, 150, 100)), "DeathCoil": ("➿", (110, 70, 150)), "Plague": ("🦠", (120, 170, 70)),
    "GuardianSpirit": ("🧚", (160, 220, 230)), "AncestralCall": ("🔔", (210, 180, 90)), "SpiritStorm": ("⛈", (110, 130, 180)),
    "SoulHarvest": ("🌾", (180, 160, 90)), "AncestralWrath": ("🏺", (190, 120, 70)),
}

# statuses: id: (kind, glyph, (r, g, b)); kinds: Shield, Buff, Debuff, Dot, Cc
STATUSES = {
    "Aegis": ("Buff", "🏵", (240, 210, 140)), "ArcaneCharge": ("Debuff", "✳", (170, 120, 255)),
    "ArcaneSurge": ("Buff", "🌌", (170, 110, 235)), "Bleeding": ("Dot", "🩸", (225, 55, 65)),
    "Blessed": ("Buff", "🙌", (255, 235, 150)), "Burning": ("Dot", "♨", (255, 130, 50)),
    "Chilled": ("Debuff", "🥶", (130, 210, 255)), "Consecrated": ("Debuff", "🌞", (255, 225, 130)),
    "Cursed": ("Debuff", "🧿", (175, 95, 225)), "DeadEye": ("Buff", "👀", (245, 185, 70)),
    "Emboldened": ("Buff", "🦸", (245, 150, 70)), "Enraged": ("Buff", "🤬", (235, 70, 60)),
    "Evasive": ("Buff", "💨", (110, 215, 190)), "Exposed": ("Debuff", "🔓", (240, 150, 90)),
    "Fortified": ("Buff", "🏯", (120, 160, 230)), "Frenzied": ("Buff", "😤", (235, 70, 80)),
    "Frozen": ("Cc", "🧊", (175, 230, 255)), "GuardianAngel": ("Buff", "😇", (255, 245, 200)),
    "Hasted": ("Buff", "🏃", (120, 225, 235)), "IronSkin": ("Buff", "🦾", (150, 165, 195)),
    "Judged": ("Debuff", "📛", (255, 230, 160)), "LastStand": ("Buff", "🧗", (235, 110, 70)),
    "Marked": ("Debuff", "❌", (255, 95, 95)), "Opened": ("Debuff", "💔", (230, 230, 120)),
    "Poisoned": ("Dot", "🤢", (130, 225, 90)), "Rallied": ("Buff", "🎺", (250, 200, 80)),
    "Shadowed": ("Debuff", "🌑", (120, 100, 170)), "Shield": ("Shield", "🔷", (90, 175, 255)),
    "Snared": ("Debuff", "⛓", (190, 150, 95)), "SoulRot": ("Debuff", "🕯", (150, 110, 190)),
    "Stunned": ("Cc", "💫", (255, 235, 90)), "Sundered": ("Debuff", "💥", (200, 160, 120)),
    "Taunting": ("Buff", "😠", (240, 120, 80)), "TeamAura": ("Buff", "🎖", (255, 210, 110)),
    "Tracked": ("Debuff", "🧭", (120, 220, 140)), "Unbreakable": ("Buff", "💎", (110, 170, 240)),
}

ULTIMATES = {
    "SanctifiedCharge": ("🐎", (230, 190, 90)), "BulwarkOfDawn": ("🌅", (240, 160, 90)), "RadiantJudgment": ("🔱", (245, 215, 110)),
    "HolyCataclysm": ("🔆", (240, 130, 70)), "BlessedBarrage": ("🎐", (190, 210, 120)), "SacredBlades": ("⚜", (210, 200, 150)),
    "SpiritChoir": ("🎶", (150, 210, 220)), "ArcaneArrowstorm": ("🧝", (120, 130, 220)), "Shadowflame": ("🖤", (150, 70, 170)),
    "SpectralTempest": ("🌊", (110, 170, 200)), "RunicSmash": ("🛠", (160, 110, 200)), "HailOfBlades": ("🌧", (130, 160, 180)),
    "WildHunt": ("🦌", (110, 160, 90)), "WarbandVolley": ("🎌", (200, 100, 70)), "ShadowLegion": ("👥", (80, 70, 120)),
    "DuelOfSteel": ("⚔", (180, 190, 205)), "GraveGuard": ("🪦" if False else "🏴", (90, 120, 100)),
}

PET_SKILLS = {
    "Goo Bubble": ("💧", (100, 200, 120)), "Fox Fire": ("🦊", (230, 120, 50)), "Mossy Guard": ("🍀", (80, 150, 100)),
    "Rockfall": ("⛰", (140, 130, 120)), "Soft Landing": ("☁", (190, 210, 235)), "Cheerful Song": ("🎵", (230, 180, 80)),
    "Spark": ("🔌", (230, 220, 90)), "Ember Claw": ("🐾", (200, 80, 50)), "Tidal Shell": ("🐚", (70, 140, 200)),
    "Tailwind": ("🪁" if False else "🎏", (120, 200, 190)), "Cold Snap": ("🍧", (120, 190, 235)), "Star Wish": ("🌠", (240, 220, 120)),
    "Thorn Armor": ("🌵", (90, 140, 70)), "Dragonfire": ("🐲", (210, 70, 50)), "Colossal Stomp": ("🦶", (150, 110, 80)),
    "Aurora Veil": ("🌈", (140, 200, 220)), "Royal Decree": ("👑", (240, 200, 80)), "Victory March": ("🏆", (150, 210, 110)),
    "Banner Guard": ("🏁", (210, 90, 80)), "Halo Mend": ("⭐", (250, 235, 160)), "Arcane Echo": ("📢", (150, 120, 220)),
    "Charter Flame": ("🏮", (230, 120, 60)), "Hawk Strike": ("🐦", (160, 130, 90)), "Hearth Ward": ("🏠", (200, 130, 90)),
    "Hearthstorm": ("🎑", (220, 110, 70)), "Mimic Bite": ("🎁", (170, 120, 60)), "Oath Mantle": ("🧣", (180, 80, 90)),
    "Rallying Bolt": ("🌂", (220, 200, 90)), "Shadow Pounce": ("🐈", (80, 70, 110)), "Spirit Link": ("🎗", (150, 210, 220)),
    "Watchful Mend": ("🦉", (160, 140, 110)),
}

PASSIVES = {
    "IronHide": ("🐘", (90, 110, 150)), "TreasureSense": ("🗝", (200, 165, 60)), "BruteForce": ("🥊", (190, 80, 70)),
    "Vitality": ("❤", (200, 70, 80)), "QuickStudy": ("📝", (120, 100, 200)), "FortuneSeeker": ("🍀" if False else "🎲", (190, 110, 170)),
    "HolyLight": ("🕯" if False else "💡", (240, 220, 130)), "Tithe": ("🪙" if False else "💰", (200, 165, 60)),
    "Devotion": ("📿", (210, 180, 120)), "Warding": ("🧷", (110, 150, 200)), "Scholar": ("🎓", (120, 100, 200)),
    "Providence": ("🌠" if False else "🍯", (190, 110, 170)),
    "ArcanePower": ("🪄" if False else "🎩" if False else "🧙", (150, 90, 210)), "Alchemy": ("⚗", (200, 165, 60)),
    "Focus": ("🧘", (190, 80, 70)), "WardedRobes": ("👘", (90, 110, 170)), "Wisdom": ("🦉" if False else "📚", (120, 100, 200)),
    "Gemcutter": ("💠" if False else "💍" if False else "🔹", (190, 110, 170)),
    "SteadyAim": ("🎳", (190, 80, 70)), "Scavenger": ("🦝" if False else "🧺", (200, 165, 60)), "Fletching": ("🪶" if False else "🦃", (170, 120, 80)),
    "Camouflage": ("🌲", (80, 130, 80)), "Tracker": ("🐕", (120, 100, 200)), "KeenEye": ("🧐", (190, 110, 170)),
    "Nimble": ("🐇", (190, 80, 70)), "Pickpocket": ("👛", (200, 165, 60)), "Lethality": ("🦂", (170, 50, 60)),
    "Fleetfoot": ("👟", (90, 140, 170)), "Streetwise": ("🗺", (120, 100, 200)), "Fence": ("💼", (190, 110, 170)),
    "SpiritBond": ("👐", (150, 120, 200)), "Tribute": ("🏦", (200, 165, 60)), "Dominion": ("🖐", (160, 60, 120)),
    "Vampirism": ("🍷", (150, 40, 60)), "Occultist": ("🔯", (120, 100, 200)), "Medium": ("🎴", (190, 110, 170)),
}


# Each class has a colour family: every class skill and passive tile is blended toward it (CLASS_SHARE), and the UI draws
# a band in the class colour on the tile, so a Warrior skill reads as Warrior at a glance (owner 2026-11-26).
CLASSES = {
    "Warrior": (178, 58, 46),   # crimson steel
    "Cleric": (226, 186, 84),   # holy gold
    "Mage": (58, 112, 214),     # arcane blue
    "Ranger": (64, 146, 72),    # forest green
    "Rogue": (128, 58, 158),    # shadow purple
    "Summoner": (54, 150, 132), # spirit teal
}
CLASS_SHARE = 0.55


def class_of(rel, idpat):
    """{ id: class } from a Config file whose entries carry Id = "..." and then Class = "..."."""
    text = open(os.path.join(ROOT, rel), encoding="utf-8").read()
    out = {}
    for m in re.finditer(r'Id = "(\w+)"(.*?)(?=Id = "|\Z)', text, re.S):
        c = re.search(r'Class = "(\w+)"', m.group(2))
        if c and c.group(1) in CLASSES:
            out.setdefault(m.group(1), c.group(1))
    return out


def tint(color, cls):
    base = CLASSES.get(cls)
    if not base:
        return color
    return tuple(int(round(color[i] * (1 - CLASS_SHARE) + base[i] * CLASS_SHARE)) for i in range(3))


def lua_color(c):
    return "{ %d, %d, %d }" % c


def lua_key(k):
    return k if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", k) else '["%s"]' % k


def write_lua():
    out = ["--[[",
           "\tIconLooks (ModuleScript, data only): the glyph and tile colour of every skill, status, ultimate, pet skill and passive.",
           "\tGENERATED by tools/icons/icons.py (edit the lists there and run it): that script checks every glyph is used once",
           "\tand is an emoji Roblox can draw (Unicode emoji 12.0 or older).",
           "",
           "\t  Skills[abilityId]     = { Glyph, Color = {r,g,b} }",
           "\t  Statuses[statusId]    = { Kind, Glyph, Color }   Kind: Shield | Buff | Debuff | Dot | Cc",
           "\t  Ultimates[id], PetSkills[skill name], Passives[id] = { Glyph, Color }",
           "\t  Classes[classId] = { Color }; skills and passives carry Class and are tinted toward it",
           "]]", "", "return {"]
    skill_class = class_of("src/shared/Config/Abilities.luau", None)
    passive_class = class_of("src/shared/Config/Passives.luau", None)
    def block(name, table, kind=False, classes=None):
        out.append("\t%s = {" % name)
        for k, v in table.items():
            if kind:
                out.append('\t\t%s = { Kind = "%s", Glyph = "%s", Color = %s },' % (lua_key(k), v[0], v[1], lua_color(v[2])))
            else:
                cls = classes and classes.get(k)
                extra = ', Class = "%s"' % cls if cls else ""
                out.append('\t\t%s = { Glyph = "%s", Color = %s%s },' % (lua_key(k), v[0], lua_color(tint(v[1], cls)), extra))
        out.append("\t},")
    out.append("\tClasses = {")
    for k, c in CLASSES.items():
        out.append("\t\t%s = { Color = %s }," % (k, lua_color(c)))
    out.append("\t},")
    block("Skills", SKILLS, classes=skill_class)
    block("Statuses", STATUSES, True)
    block("Ultimates", ULTIMATES)
    block("PetSkills", PET_SKILLS)
    block("Passives", PASSIVES, classes=passive_class)
    out.append("}")
    path = os.path.join(ROOT, "src", "shared", "Config", "IconLooks.luau")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    return path


def config_glyphs(rel, pattern):
    text = open(os.path.join(ROOT, rel), encoding="utf-8").read()
    return [(m.group(1), m.group(2)) for m in re.finditer(pattern, text)]


def main():
    entries = []
    for k, v in SKILLS.items(): entries.append(("skill " + k, v[0]))
    for k, v in STATUSES.items(): entries.append(("status " + k, v[1]))
    for k, v in ULTIMATES.items(): entries.append(("ultimate " + k, v[0]))
    for k, v in PET_SKILLS.items(): entries.append(("pet skill " + k, v[0]))
    for k, v in PASSIVES.items(): entries.append(("passive " + k, v[0]))
    for k, g in config_glyphs("src/shared/Config/Talents.luau", r'(\w+) = \{ Name = "[^"]*", Glyph = "([^"]+)"'): entries.append(("talent " + k, g))
    for k, g in config_glyphs("src/shared/Config/Runes.luau", r'(\w+) = \{ Name = "[^"]*", Glyph = "([^"]+)"'): entries.append(("rune " + k, g))
    for k, g in config_glyphs("src/shared/Config/Consumables.luau", r'Id = "(\w+)",[^\n]*Glyph = "([^"]+)"'): entries.append(("consumable " + k, g))

    problems = 0
    seen = {}
    for who, glyph in entries:
        base = glyph.replace("️", "")
        if base in seen:
            print("DUPLICATE %s  %s and %s" % (glyph, seen[base], who)); problems += 1
        else:
            seen[base] = who
    test = sys.argv[1] if len(sys.argv) > 1 else None
    if test and os.path.exists(test):
        version = {}
        for line in open(test, encoding="utf-8"):
            m = re.match(r"^([0-9A-F ]+?)\s*;\s*[\w-]+\s*#\s*\S+\s+E(\d+\.\d+)", line)
            if m:
                s = "".join(chr(int(h, 16)) for h in m.group(1).split()).replace("️", "")
                version[s] = min(version.get(s, 99.0), float(m.group(2)))
        for who, glyph in entries:
            v = version.get(glyph.replace("️", ""))
            if v is None:
                print("NOT AN EMOJI %s  %s" % (glyph, who)); problems += 1
            elif v > 12.0:
                print("TOO NEW (E%.1f) %s  %s" % (v, glyph, who)); problems += 1
    print("%d glyphs, %d problems" % (len(entries), problems))
    if problems == 0:
        print("wrote", write_lua())
    return problems


if __name__ == "__main__":
    sys.exit(1 if main() else 0)
