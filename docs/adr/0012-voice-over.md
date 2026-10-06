# ADR 0012: Voice-over with ElevenLabs

Status: accepted (owner decision 2026-10-06: "lets start generating spoken audio using elevenlabs")

## Context

Plan §5.7 writes every line as text first and names the Narrator as the best candidate for voice-over (open question
§13.4). The owner chose ElevenLabs and asked for spoken audio for the dialogue and narration. Dialogue is still
being written and edited (Phase 5 now, Phase 6 to come), so audio must follow the text without paying twice for a
line that hasn't changed, and the game must work with any mix of voiced and unvoiced lines.

## Decision

- **Provider and model pinned** in `audio/voice/casting.json`: ElevenLabs `eleven_v4`, `mp3_44100_64` (speech at
  64 kbps keeps the repository small; Godot imports MP3 natively). Every clip in the game comes from that model, as
  every image comes from the pinned Gemini model. The key is `ELEVENLABS_API_KEY`, read from the environment or
  `~/.zshrc` and sent as the `xi-api-key` header, never written anywhere.
- **A clip is keyed by its speaker and its text**: `res://audio/voice/<speaker>/<key>.mp3`, where `<key>` is the
  first 16 hex digits of the SHA-1 of the line's trimmed text and `<speaker>` is `narrator` or an npc id. The
  dialogue files need no line ids. An edited line gets a new key, so only new or changed lines are generated; the
  same line written twice shares one clip; `make voice PRUNE=1` removes clips no line uses any more.
- **What is voiced** (`tools/audio/voice_lines.py`): NPC lines and story allies' (`guest:`) interjections, Madam
  Eva's Tarokka verses, the Narrator's conversation lines and trigger variants, and the Narrator text in location and
  travel data (first visit, encounter intros, traps, barred exits). **Not voiced:** options, rolls and notices,
  party members' lines and banter (the player's own characters), books and letters, and lines holding `{name}`,
  `{leader}` or `{target}` (filled in at run time). Those stay text.
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
  combat log's Narrator lines speak.

## Consequences

- Writers keep writing text; a line is voiced by running `make voice` after it lands, and costs only its own
  characters. Rewording a voiced line costs a new clip.
- The repository grows by roughly 8 KB per second of speech (about 400 MB for every line written by Phase 5).
- Party lines, `{name}` lines and Phase 6 content are silent until a later decision voices them.
