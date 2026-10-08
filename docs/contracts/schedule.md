# Schedule: things on a clock (F2)

`data/schedule/<region>.json` (schema: schedule.schema.json) holds events that happen on a day and an hour, read by
`story/schedule.gd`. LocationClock (world/exploration/location_clock.gd) asks `Schedule.catch_up` whenever the clock has
moved while the party is in a location, outside fights and conversations.

```json
{"id": "vallaki", "region": "vallaki", "events": [
  {"id": "vallaki_arrest", "hour": 8, "every_days": 3, "first_day": 2, "location": "vallaki",
   "when": "flag.vallaki_arrived", "set": {"vallaki_stocks_grumbler": true}, "narration": "A drum, then boots..."}]}
```

- **When:** `hour` (and `minute`), every day or every `every_days` days from `first_day`, while `when` holds (checked
  when the event comes due). `once` events happen a single time.
- **What it does:** sets its `set` flags wherever the party is. If the party is at its `location` (or it has none),
  within an hour of its time, it also plays a Narrator `narration` line or starts a `dialogue`.
- **Catching up:** a long wait (a Long Rest, a journey) brings each event round once, at its latest time in the wait,
  not once per day missed. `here_only` events wait for a day the party is there to see them.
- **Memory:** `StoryState.flags["_schedule"]` = `{last: minute, fired: {id: times}}`, so it survives saves; a game or
  save without it starts counting from the moment it is first looked at.
- **People keeping hours** is the location NPC entries' `hours` (docs/contracts/locations.md), not this file.
