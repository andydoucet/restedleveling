#!/usr/bin/env bash
# Renders Rested Leveling in wow-ui-sim (Forever build), from the real addon code, into <outdir>:
#   tools/render.sh <outdir> [scene-filter]
# Each scene in tools/sim/scenes/NN_name.lua runs in a fresh sandbox: a copy of the addon, the render fixture
# (tools/sim/fixture: Andy's roster as saved data, a pinned clock) and, for *_elvui scenes, read-only copies of
# ElvUI + ElvUI_WC3 with a sim shim. Never touches the real WTF or AddOns. Exits non-zero on any Lua error from our
# addon. Writes at most 16 PNGs named scene_NN_<name>.png.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:?usage: tools/render.sh <outdir> [filter]}
FILTER=${2:-}
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)

SIM=${WOW_SIM:-$HOME/.local/opt/wow-ui-sim/wow-ui-sim-v0.1.40-forever-linux-x86_64/wow-sim}
ELV_RO=${RL_ELVUI_RO:-$HOME/Projects/rested-leveling-desk/addons-ro}
export WOW_INSTALL_PATH=${WOW_INSTALL_PATH:-"/data/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft"}
export WOW_SIM_NO_SOUND=1
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export TMPDIR=${RL_TMPDIR:-$HOME/.cache/rested-leveling/tmp}
mkdir -p "$TMPDIR"
WORK=$(mktemp -d "$TMPDIR/render.XXXXXX")
trap '[[ -n "${RL_KEEP:-}" ]] || rm -rf "$WORK"' EXIT

# The addon as the game would load it: only what the TOC lists, plus media.
stage_addon() {
	local dest=$1/RestedLeveling
	mkdir -p "$dest"
	cp "$ROOT/RestedLeveling.toc" "$dest/"
	grep -v '^\s*#' "$ROOT/RestedLeveling.toc" | tr -d '\r' | grep -E '\.lua$' | tr '\\' '/' | while read -r f; do
		mkdir -p "$dest/$(dirname "$f")"
		cp "$ROOT/$f" "$dest/$f"
	done
	cp -r "$ROOT/media" "$dest/media"
	rm -rf "$dest/media/src"
}

fail=0
count=0
for scene in "$ROOT"/tools/sim/scenes/[0-9][0-9]_*.lua; do
	name=$(basename "$scene" .lua)
	[[ -n "$FILTER" && "$name" != *"$FILTER"* ]] && continue
	count=$((count + 1))
	[[ $count -gt 16 ]] && { echo "more than 16 scenes" >&2; exit 2; }
	box="$WORK/$name"
	mkdir -p "$box/AddOns" "$box/wtf"
	stage_addon "$box/AddOns"
	cp -r "$ROOT/tools/sim/fixture" "$box/AddOns/!RLSimFixture"
	style=default
	if [[ "$name" == *_elvui* ]]; then
		style=elvui
		cp -r "$ELV_RO/ElvUI" "$ELV_RO/ElvUI_Libraries" "$ELV_RO/ElvUI_WC3" "$box/AddOns/"
		chmod -R u+w "$box/AddOns"   # the read-only copies stay read-only; the sandbox copy must be removable
		cp -r "$ROOT/tools/sim/elvui" "$box/AddOns/!RLSimElvUI"
	fi
	# Per-scene options from a "-- render:" header line: --width/--height/--crop pass to the screenshot,
	# --empty starts from an empty roster (first run), --case <name> picks a fixture case (tools/sim/fixture).
	opts=$(sed -n 's/^-- render: //p' "$scene" | head -1)
	width=1920 height=1080 crop=() empty=false case=
	read -r -a words <<<"$opts"
	for ((i = 0; i < ${#words[@]}; i++)); do
		case "${words[$i]}" in
			--empty) empty=true ;;
			--case) case=${words[$((i + 1))]}; i=$((i + 1)) ;;
			--width) width=${words[$((i + 1))]}; i=$((i + 1)) ;;
			--height) height=${words[$((i + 1))]}; i=$((i + 1)) ;;
			--crop) crop=(--crop "${words[$((i + 1))]}"); i=$((i + 1)) ;;
		esac
	done
	shot=(--width "$width" --height "$height" "${crop[@]}")
	printf "RLFIX_STYLE = '%s'\nRLFIX_EMPTY = %s\nRLFIX_CASE = '%s'\n" "$style" "$empty" "$case" > "$box/AddOns/!RLSimFixture/Style.lua"
	sed -i 's/^Fixture.lua$/Style.lua\nFixture.lua/' "$box/AddOns/!RLSimFixture/!RLSimFixture.toc"
	# The scene runs as sandbox code 4 s after PLAYER_ENTERING_WORLD (our login work runs at +2 s), inside the startup
	# delay, so animations such as the card's speech typewriter finish before the screenshot.
	{
		echo 'local RLScene = CreateFrame("Frame"); RLScene:RegisterEvent("PLAYER_ENTERING_WORLD")'
		echo 'RLScene:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); C_Timer.After(4, function()'
		cat "$ROOT/tools/sim/scenes/_prelude.lua" "$scene"
		# ElvUI scenes: the skin's art must be on our windows, checked after the skin has applied.
		[[ "$style" == elvui ]] && echo 'C_Timer.After(1, function() RLCheckWC3(RestedLevelingMain, "RestedLevelingMain") end)'
		echo 'end) end)'
	} > "$box/AddOns/!RLSimFixture/Scene.lua"
	echo "Scene.lua" >> "$box/AddOns/!RLSimFixture/!RLSimFixture.toc"
	cat "$ROOT/tools/sim/scenes/_prelude.lua" > "$box/scene.lua"
	log="$box/sim.log"
	set +e
	nice -n 15 ionice -c3 "$SIM" --allow-ui-version-mismatch --no-saved-vars --addons-path "$box/AddOns" \
		--class Shaman --race Orc --delay 9000 --exec-lua "@$box/scene.lua" \
		screenshot --session-wtf-path "$box/wtf" --png "${shot[@]}" -o "$OUT/scene_$name.png" >"$log" 2>&1
	rc=$?
	set -e
	errs=$(grep -a -E "Lua error|Lua Error|RLSIM_CHECK" "$log" | grep -a -v "RLSIM_CROP" | grep -a -E "RestedLeveling|RLSim|scenes/|RLSIM_CHECK" | sort -u || true)
	if [[ $rc -ne 0 || -n "$errs" || ! -s "$OUT/scene_$name.png" ]]; then
		echo "FAIL $name (exit $rc)"
		[[ -n "$errs" ]] && echo "$errs" | head -20
		fail=1
		cp "$log" "$OUT/$name.log"
	else
		# A scene that called RLCrop(...) is cropped to our frames plus a 40 px margin, at 1:1 pixels (no scaling),
		# so the text is seen at its true size. Scenes without it (01, the full-screen context shot) stay whole.
		box_frac=$(grep -a -o "RLSIM_CROP [0-9. ]*" "$log" | head -1 | cut -d' ' -f2- || true)
		if [[ -n "$box_frac" ]]; then
			python3 - "$OUT/scene_$name.png" $box_frac <<'PY'
import sys
from PIL import Image
path, l, b, r, t = sys.argv[1], *map(float, sys.argv[2:6])
im = Image.open(path)
W, H = im.width, im.height
m = int(float(sys.argv[6])) if len(sys.argv) > 6 else 40
box = (max(0, int(l * W) - m), max(0, int((1 - t) * H) - m), min(W, int(r * W) + m), min(H, int((1 - b) * H) + m))
im.crop(box).save(path)
PY
		fi
		echo "ok   scene_$name.png${box_frac:+ (cropped 1:1)}"
	fi
done
exit $fail
