# Godot slots (owner, 2026-10-18): the Mac has 24 GB and every lane runs imports and tests, so past about a dozen Godot
# processes it swaps and everything runs slower (13 import editors at ~1.8 GB each and 21 test processes at ~0.8 GB
# were wanted at once: load 82, swap 20 GB). A slot is a folder <root>/<pool>/<n> holding the PID of the process that
# has it; <pool> is "import" (the editor, IMPORT_SLOTS, 3) or "test" (a headless test process, TEST_SLOTS, 8), shared
# by every lane and every checkout. A slot whose PID is gone is cleared, and so is one with no PID for a minute.
# tools/run_tests.py takes its test slots the same way. GODOT_SLOTS=off turns the cap off. Where the folder can't be
# made, nothing is capped. A launch the owner plays (make run, run-main, arena) runs its pre-play import with
# GODOT_SLOTS=off: it never waits for a slot, takes none, and a running game holds none, so lanes keep all of theirs.
#
# The build lane (owner, 2026-10-18): the thread that merges, tests and pushes shares the Mac with every development
# lane, and its runs sat in the same queue (a lane run waited up to an hour, a make check took 4 to 7 minutes, a full
# ci 47). So the top slots of each pool are kept for it: BUILD_TEST_SLOTS (5) of the 8 test slots, 4 to 8, and
# BUILD_IMPORT_SLOTS (1) of the 3 import slots, 3. A development lane only ever claims the others (1 to 3 and 1 to 2),
# so it can never hold a reserved slot, and the build lane always has them free. The build lane tries the reserved slots
# first and then the others, so it can use all 8 and 3 when the lanes leave room, and the lanes keep what it doesn't
# need. The totals stay 8 and 3: the reservation moves slots, it adds none (the Mac was at 88% swap and load 40 with
# them full). A run is the build lane's when BUILD_LANE is set (anything but empty or 0), or when the checkout holds
# .godot/build-lane with its own absolute path in it (`pwd -P > .godot/build-lane` once in the folder; a copy of .godot
# in another folder names the wrong path and counts for nothing). Only the build thread opts in. TEST_SLOTS and
# IMPORT_SLOTS still cut a run's slots down to 1..n (the build lane's n first slots, reserved ones first).
#
# Sourced by tools/import.sh: take_slot <pool> <limit> waits for a free one; free_slot gives it back.
slot_root="${STRAHD_SLOT_ROOT:-/tmp/strahd-godot-slots-$(id -u)}"
slot_checkout="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
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

## Whether this run is the build lane's: BUILD_LANE, or the folder's own .godot/build-lane marker.
slot_build_lane() {
  case "${BUILD_LANE:-}" in
    "" | 0) [ "$(cat "$slot_checkout/.godot/build-lane" 2> /dev/null || true)" = "$slot_checkout" ] ;;
    *) return 0 ;;
  esac
}

## The slot numbers a run may claim, in the order it tries them: slot_candidates <pool> <limit> <build: 1 or 0>.
## The pool's size is the default of its limit (8 test slots, 3 import slots); the last BUILD_<POOL>_SLOTS of those are
## the build lane's. The reserve stays below the size, so the lanes always have a slot.
slot_candidates() {
  local pool="$1" limit="$2" build="$3" size reserve first i dev="" kept=""
  [ "$limit" -ge 1 ] || limit=1   # BSD seq counts down from 1 to 0
  case "$pool" in
    test) size=8 reserve="${BUILD_TEST_SLOTS:-5}" ;;
    import) size=3 reserve="${BUILD_IMPORT_SLOTS:-1}" ;;
    *) size="$limit" reserve=0 ;;
  esac
  case "$reserve" in "" | *[!0-9]*) reserve=$((size == 8 ? 5 : 1)) ;; esac
  [ "$reserve" -lt "$size" ] || reserve=$((size - 1))
  first=$((size - reserve + 1))
  for i in $(seq 1 "$limit"); do
    if [ "$i" -lt "$first" ] || [ "$i" -gt "$size" ]; then dev="$dev $i"; fi
  done
  if [ "$build" = 1 ]; then
    for ((i = first; i <= size; i++)); do kept="$kept $i"; done
    set -- $kept $dev
    echo "${@:1:$limit}"
  else
    echo $dev
  fi
}

## One pass over the slots this run may claim: 0 with held_slot set when it got one, 1 when they are all in use.
try_slot() {
  local pool="$1" limit="$2" dir="$slot_root/$1" build=0 i slot
  slot_build_lane && build=1
  for i in $(slot_candidates "$pool" "$limit" "$build"); do
    slot="$dir/$i"
    if [ -d "$slot" ] && slot_stale "$slot"; then rm -rf "$slot"; fi
    if mkdir "$slot" 2> /dev/null; then
      echo $$ > "$slot/pid"
      pwd > "$slot/where"
      [ "$build" = 0 ] || echo build > "$slot/build"
      held_slot="$slot"
      return 0
    fi
  done
  return 1
}

take_slot() {
  local pool="$1" limit="$2" told="" lanes build=0
  [ "${GODOT_SLOTS:-}" != off ] || return 0
  mkdir -p -m 700 "$slot_root/$pool" 2> /dev/null || return 0
  until try_slot "$pool" "$limit"; do
    if [ -z "$told" ]; then
      slot_build_lane && build=1
      lanes="$(slot_candidates "$pool" "$limit" 0 | wc -w | tr -d ' ')"
      if [ "$build" = 1 ]; then
        echo "make $pool: waiting for a Godot slot (the build lane: up to $limit at once, the reserved ones first;" \
          "$(printf %s "$pool" | tr a-z A-Z)_SLOTS=n changes it)" >&2
      else
        echo "make $pool: waiting for a Godot slot ($lanes at once for the development lanes across all lanes, the" \
          "rest kept for the build lane; $(printf %s "$pool" | tr a-z A-Z)_SLOTS=n changes it)" >&2
      fi
    fi
    told=1
    sleep $((2 + RANDOM % 3))
  done
}

free_slot() { [ -z "$held_slot" ] || rm -rf "$held_slot"; held_slot=""; }
