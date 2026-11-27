#!/usr/bin/env bash
# The council's renders: at most 8 PNGs, scene_NN_<name>.png, from tools/sim/council/NN_<name>.lua, in wow-ui-sim with
# the real addon (see tools/render.sh: sandboxed copies only, never the game install or WTF; exits non-zero on any
# Lua error from our addon). Scenes use the "v112" fixture: Andy's roster from his 1.1.2 screenshot
# (refs/ingame/andy_v112_main.png), plus a saved-look stand-in and a character on his linked account.
#   tools/render_council.sh <outdir> [scene-filter]
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:?usage: tools/render_council.sh <outdir> [filter]}
mkdir -p "$OUT"
rm -f "$OUT"/scene_*.png "$OUT"/*.log
RL_SCENES="$ROOT/tools/sim/council" RL_MAX_SCENES=8 exec "$ROOT/tools/render.sh" "$OUT" "${2:-}"
