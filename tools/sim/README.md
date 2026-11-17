# Headless tests and balance simulation

Roblox code is plain Luau, so the pure `src/shared` modules and the test suites run outside Studio with the standalone
`luau` binary (https://github.com/luau-lang/luau/releases). `sync.py` copies `src` into `.build/hl6` and rewrites the
Roblox `require(script.Parent...)` calls into file requires.

- `./runall.sh`  all test suites (every suite must end "0 failed"). `LUAU=/path/to/luau ./runall.sh` if luau is not on PATH.
- `./abl.sh tag goal mode Class|Path`  balance simulation (see the header of the script). Read `RESULT` and `BOSS` lines:
  `BOSS 20:90m/139m/60x/7s` = reached stage 19 at 90 min, beat boss 20 at 139 min after 60 losses.
- `runners/extra.luau` registers newer test suites; add new ones there AND keep Studio's runner list in mind.
- Test files use `warn or print`; `warn` is nil in this harness, so debug with `print`.
- `.build/` is generated; do not commit it.
