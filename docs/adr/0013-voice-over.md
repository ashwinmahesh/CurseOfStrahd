# ADR 0013: Voice-over with ElevenLabs

Status: accepted (owner decision 2026-10-06: "lets start generating spoken audio using elevenlabs")

## Context

Plan §5.7 writes every line as text first and names the Narrator as the best candidate for voice-over (open question
§13.4). The owner chose ElevenLabs and asked for spoken audio for the dialogue and narration. Dialogue is still
being written and edited (Phase 5 now, Phase 6 to come), so audio must follow the text without paying twice for a
line that hasn't changed, and the game must work with any mix of voiced and unvoiced lines.

## Decision

- **Provider and model pinned** in `audio/voice/casting.json`: ElevenLabs `eleven_v4`, `mp3_44100_64` (speech at
  64 kbps keeps the repository small; Godot imports MP3 natively). A speaker can name their own model there instead
  (owner, 2026-10-07): the Barovians, the Vistani and the castle's people speak on `eleven_v3`, which keeps the
  Eastern European accents `eleven_v4` flattens; everyone else, the Narrator and the party among them, stays on
  `eleven_v4`. The key is `ELEVENLABS_API_KEY`, read from the environment or
  `~/.zshrc` and sent as the `xi-api-key` header, never written anywhere.
- **A clip is keyed by its speaker and its text**: `res://audio/voice/<speaker>/<key>.mp3`, where `<key>` is the
  first 16 hex digits of the SHA-1 of the line's trimmed text and `<speaker>` is `narrator`, an npc id, a prebuilt
  hero's id or a custom hero's voice (`hero_female`, `hero_male`). The
  dialogue files need no line ids. An edited line gets a new key, so only new or changed lines are generated; the
  same line written twice shares one clip; `make voice PRUNE=1` removes clips no line uses any more.
- **What is voiced** (`tools/audio/voice_lines.py`): NPC lines and story allies' (`guest:`) interjections, Madam
  Eva's Tarokka verses, the Narrator's conversation lines, banter lines and trigger variants, the Narrator text in
  location and travel data (first visit, encounter intros, traps, barred exits), and the party's lines (owner,
  2026-10-06): a hero's `name:` lines in that hero's voice, and every line any party member could say (`class:`,
  `species:`, `background:`, `tag:` interjections and banter, "Player:") in the voice of each prebuilt hero it fits
  and in both custom-hero voices, because a custom character (`build.appearance.custom`) speaks in the voice the
  player picked (`build.appearance.voice`). **Not voiced:** options, rolls and notices, books and letters, and lines
  holding `{name}`, `{leader}` or `{target}` (filled in at run time). Those stay text.
- **Casting** is per speaker in `casting.json` (an ElevenLabs voice id, a name, the description it was designed
  from and optional settings). Voices are auditioned with `tools/audio/audition.py` (Voice Design from the speaker's
  voice bible, or a library voice) and the owner picks the Narrator.
- **Generation** (`make voice [SPEAKER="narrator ..."] [LIMIT=n] [DRY=1] [MAX_USD=n]`): only missing clips, a cost
  estimate before anything is spent and a cap per run (default $5), every call logged in
  `audio/voice/generation_log.jsonl`, and `audio/voice/manifest.json` recording what made each clip, so a recast
  (`RECAST=1`) regenerates only that speaker's clips.
- **Playback** is `VoiceOver` (`core/voice_over.gd`): `say(speaker, text)` plays the line's clip on a `Voice` bus
  and returns its length (0 when there is none, so unvoiced lines are silent); one voice at a time; its own volume
  (`VoiceOver.set_volume`, kept in `user://settings.cfg` as `[audio] voice`) for a Voices slider beside Music and
  Effects in the pause menu. Hooks: the conversation screen speaks each line
  beat and stops on any other beat, the explore HUD's Narrator box speaks and stays up until the voice ends, and the
  combat log's Narrator lines speak. `beat_voice(beat)` finds a party member's voice (`voice_for`), and banter
  plays line by line in each speaker's voice (`say_all`) while the box stays up (`hold_narration`).

## Casting decisions (owner, 2026-10-06)

- **The Narrator** is a designed voice in the style of the Baldur's Gate 3 narrator (a low, warm English woman,
  intimate and wryly amused), picked from auditions; nothing is cloned from a real person.
- **Accents:** Barovians, the Vistani and Strahd speak with a strong, clearly audible Eastern European (Romanian)
  accent; outsiders keep their own (Van Richten Dutch, the Silver Dragon knights, Exethanter and Vosk English).
- **Main characters** (the Narrator and 26 leads) keep saved voices on the account, for new and edited lines.
- **Minor characters** each get a voice designed from their description, used for their lines and then deleted from
  the account (`audition.py release`, `"released": true` in casting.json) to stay within the plan's 30 voice slots.
  Their clips stay; a new or edited line for one of them needs a newly designed voice (`audition.py auto`).
- **The party:** Hedda, Ilse, Silvain and Tamsin have designed voices with their own accents (a soft Scottish lilt,
  a light German accent, refined English, a light Irish lilt); the custom character's two choices are library voices
  with a neutral English accent (Lucie, Julian Vale), which use no voice slot. Argynvost's voice was released to
  make room.
- **Children and teens:** ElevenLabs will not design voices for anyone under 18. The children use ready-made library
  voices (`"library": true`); Luminita (17) and Victor (16) have young adult voices.

## Consequences

- Writers keep writing text; a line is voiced by running `make voice` after it lands, and costs only its own
  characters. Rewording a voiced line costs a new clip.
- The repository grows by roughly 8 KB per second of speech (about 400 MB for every line written by Phase 5).
- Party lines, `{name}` lines and Phase 6 content are silent until a later decision voices them.
