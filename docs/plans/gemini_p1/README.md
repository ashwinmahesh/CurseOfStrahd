# P1 (the Tsolenka gate wards and the tower's upper floors): Gemini brief and raw reply

Same method as the NPC plan's batches (docs/plans/gemini_batch1/README.md on the npc-plan branch): the brief was sent
through the ai-bridge to Gemini on 2026-10-18 (the bridge did not report which model answered) and the reply is kept as
Gemini wrote it. The lines in the game are these, trimmed and checked for canon by Claude:

- Where Gemini gave two sentences as two lines for a Narrator trigger (`examine:`, `enter:`), they are joined into one
  line, since a Narrator trigger plays one variant at a time; the green-fire conversation keeps its lines in order, with
  the Arcana and Dispel Magic results trimmed to one line each.
- "Keystone" is gone from the Arcana line (the gate has none in the art), the sprung-trap line says "the first of you"
  instead of "you", and the tallow statue line lost "under your palm" (nobody can reach the wall's top).
- The two stone demons stand against the wall beside the gate (that is where the art can put them), so "crouches on the
  wall above the gate" became "crouches against the wall beside the gate".
- The roof knights are the game's gilded knight statue (it rests its hands on a sword's hilt), so "hold their swords up
  to the sky" became "stand ... hands folded on the hilts of their swords".
- Menu choices and prop names (for example "Study the weave for the knot that holds it", "A curtain of green fire") are
  labels, not dialogue; Claude wrote them.

- The vrock wake line (the fight's opening text) was drafted separately: "shedding from wet flesh" became "flaking off wet
  flesh", which reads better on the screen and says what the stone is doing.

- tsolenka: brief `tsolenka.brief.txt`, raw reply `tsolenka.reply.txt` (message 13547fac)
- vrocks: brief `vrocks.brief.txt`, raw reply `vrocks.reply.txt` (message ea8379bb)
- stones: brief `stones.brief.txt`, raw reply `stones.reply.txt` (message 1896257d). It replaced the first reply's two arch lines
  (`examine:tsolenka_arch_w` and `_e`) when the carved-arch piece had to go (it needs a wall; test_wall_pieces_have_a_wall). The
  western stones keep both of Gemini's lines as two variants, the eastern one line; nothing else was changed.
