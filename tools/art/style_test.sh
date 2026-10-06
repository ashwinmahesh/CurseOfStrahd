#!/usr/bin/env bash
# Phase 0 style test (plan §7 step 2): the same prompts through each candidate model.
# Usage: tools/art/style_test.sh <model>   -> art/generated/style_test/<model>/
set -uo pipefail
cd "$(dirname "$0")/../.."
M="$1"
export MODEL="$M"
G=tools/art/generate_openai.sh
$G villager_turnaround "style_test/$M" "Character turnaround sheet of a gaunt, frightened Barovian villager peasant man in a patched wool tunic, flat cap and worn boots. Exactly five full-body views of the same man in one row, left to right: front, front three-quarter, side profile facing right, back three-quarter, back. Relaxed neutral standing pose with arms at the sides, same scale and height, evenly spaced with clear gaps, isolated on a transparent background, no ground shadow." --size 1536x1024 --background transparent
$G strahd_portrait "style_test/$M" "Bust portrait of Strahd von Zarovich, an elegant gaunt vampire nobleman with slicked-back black hair, a sharp widow's peak, pale skin and red eyes, wearing a high-collared black cape with crimson lining, smirking with cold aristocratic menace, lit by candlelight from below against a dark purple background." --size 1024x1024 --background opaque
$G village_matte "style_test/$M" "Wide background matte painting of the Village of Barovia at dusk: crooked timber houses with steep roofs, a muddy road, gnarled dead trees, thick grey mist, and Castle Ravenloft silhouetted on a distant cliff under a heavy overcast sky, a few candlelit windows." --size 1536x864 --background opaque
