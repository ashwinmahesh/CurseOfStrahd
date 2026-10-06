#!/usr/bin/env bash
# The Phase 0 style test prompts for a Gemini image model (no transparency: flat white backgrounds).
# Usage: tools/art/style_test_gemini.sh [model]   -> art/generated/style_test/<model>/
set -uo pipefail
cd "$(dirname "$0")/../.."
M="${1:-gemini-3.1-flash-image}"
G="python3 tools/art/generate_gemini.py"
$G villager_turnaround "style_test/$M" "Character turnaround sheet of a gaunt, frightened Barovian villager peasant man in a patched wool tunic, flat cap and worn boots. Exactly five full-body views of the same man in one row, left to right: front, front three-quarter, side profile facing right, back three-quarter, back. Relaxed neutral standing pose with arms at the sides, same scale and height, evenly spaced with clear gaps, on a plain flat white background, no ground shadow." --model "$M" --aspect 3:2
$G strahd_portrait "style_test/$M" "Bust portrait of Strahd von Zarovich, an elegant gaunt vampire nobleman with slicked-back black hair, a sharp widow's peak, pale skin and red eyes, wearing a high-collared black cape with crimson lining, smirking with cold aristocratic menace, lit by candlelight from below against a dark purple background." --model "$M" --aspect 1:1
$G village_matte "style_test/$M" "Wide background matte painting of the Village of Barovia at dusk: crooked timber houses with steep roofs, a muddy road, gnarled dead trees, thick grey mist, and Castle Ravenloft silhouetted on a distant cliff under a heavy overcast sky, a few candlelit windows." --model "$M" --aspect 16:9
