# Godot slots (owner, 2026-10-18): the Mac has 24 GB and every lane runs imports and tests, so past about a dozen Godot
# processes it swaps and everything runs slower (13 import editors at ~1.8 GB each and 21 test processes at ~0.8 GB
# were wanted at once: load 82, swap 20 GB). A slot is a folder <root>/<pool>/<n> holding the PID of the process that
# has it; <pool> is "import" (the editor, IMPORT_SLOTS, 3) or "test" (a headless test process, TEST_SLOTS, 8), shared
# by every lane and every checkout. A slot whose PID is gone is cleared, and so is one with no PID for a minute.
# tools/run_tests.py takes its test slots the same way. GODOT_SLOTS=off turns the cap off. Where the folder can't be
# made, nothing is capped. A launch the owner plays (make run, run-main, arena) runs its pre-play import with
# GODOT_SLOTS=off: it never waits for a slot, takes none, and a running game holds none, so lanes keep all of theirs.
#
# Sourced by tools/import.sh: take_slot <pool> <limit> waits for a free one; free_slot gives it back.
slot_root="${STRAHD_SLOT_ROOT:-/tmp/strahd-godot-slots-$(id -u)}"
held_slot=""

## A slot's folder is stale when its holder is gone, or it never got to write its PID.
slot_stale() {
  local pid
  pid="$(cat "$1/pid" 2> /dev/null || true)"
  if [ -n "$pid" ]; then
    ! kill -0 "$pid" 2> /dev/null
  else
    [ -n "$(find "$1" -maxdepth 0 -mmin +1 2> /dev/null)" ]
  fi
}

take_slot() {
  local pool="$1" limit="$2" dir i slot told=""
  [ "${GODOT_SLOTS:-}" != off ] || return 0
  dir="$slot_root/$pool"
  mkdir -p -m 700 "$dir" 2> /dev/null || return 0
  while :; do
    for i in $(seq 1 "$limit"); do
      slot="$dir/$i"
      if [ -d "$slot" ] && slot_stale "$slot"; then rm -rf "$slot"; fi
      if mkdir "$slot" 2> /dev/null; then
        echo $$ > "$slot/pid"
        pwd > "$slot/where"
        held_slot="$slot"
        return 0
      fi
    done
    [ -n "$told" ] || echo "make $pool: waiting for a Godot slot ($limit at once across all lanes;" \
      "$(printf %s "$pool" | tr a-z A-Z)_SLOTS=n changes it)" >&2
    told=1
    sleep $((2 + RANDOM % 3))
  done
}

free_slot() { [ -z "$held_slot" ] || rm -rf "$held_slot"; held_slot=""; }
