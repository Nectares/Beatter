# Flow Audio Architecture

Foundational audio + figuration layer introduced for **Flow Mode**, designed to
be reused by Sheet Mode, Reading Mode, Polyrhythm Mode and the Exercises.

Flow Mode no longer generates single synthetic clicks. It now generates a
**sequence of real rhythmic figurations** and plays each figuration's own WAV.

All code lives under `lib/services/figurations/`. The old shared
`RhythmPlaybackService` is **untouched** and keeps serving the other modes.

---

## 1. Overview of the new architecture

```
                     ┌───────────────────────────┐
                     │      FlowModePage (UI)     │
                     └──────────────┬────────────┘
                                    │ listens / commands
                     ┌──────────────▼────────────┐
                     │   FlowPlaybackController   │  ChangeNotifier
                     │  (state + orchestration)   │
                     └───┬───────┬───────┬────────┘
             generate│       │when   │fire WAV
                     ▼       ▼       ▼
        ┌───────────────┐ ┌───────────────┐ ┌───────────────────────┐
        │ FlowSequence  │ │ AudioScheduler│ │  FigurationAudioCache │
        │  Generator    │ │ (beat clock)  │ │  (preloaded voices)   │
        └───────┬───────┘ └───────────────┘ └───────────────────────┘
                │ reads
        ┌───────▼────────┐
        │ FigurationLib  │  built from the asset manifest
        └───────┬────────┘
                │ of
        ┌───────▼────────┐
        │  Figuration    │  id + category + wavAsset + imageAsset + beats
        └────────────────┘
```

| Component | File | Responsibility |
|-----------|------|----------------|
| `Figuration` | `figuration.dart` | One rhythmic cell: id, category, WAV asset, notation image, musical length (beats). |
| `FigurationCategory` | `figuration.dart` | The shipped categories and their fixed beat length (`1_4`=1, `2_4`=2, `4_4`=4, `OTTAVI`=1.5). |
| `FigurationLibrary` | `figuration_library.dart` | Scans the asset manifest, indexes every figuration WAV by category. |
| `FigurationAudioCache` | `figuration_audio_cache.dart` | Preloads one `AudioPlayer` per WAV; fires them with zero runtime loading. |
| `AudioScheduler` | `audio_scheduler.dart` | Audio-agnostic, drift-free beat sequencer. Calls back per event. |
| `FlowSequenceGenerator` | `flow_sequence_generator.dart` | Builds the sequence: a chain of N movimenti from one set. |
| `FlowPlaybackController` | `flow_playback_controller.dart` | Ties it all together; owns the metronome + picker state; the only thing the UI talks to. |

### The movimento model

A Flow sequence is a plain chain of **movimenti**. Each movimento is exactly one
figuration tile; `+`/`-` changes the count by one. All movimenti in a sequence
come from a **single set**, chosen by the Ottave switch — the two sets are never
mixed:

* **Ottave OFF** — the **1/4 set** (`1_4` cells, 1.0 beat each).
* **Ottave ON** — the **eighths / 3/8 set** (`OTTAVI` cells, 1.5 beats each).

The `2_4` / `4_4` categories stay in the library (loaded, ready) but are not
drawn by Flow Mode's per-movimento generation today.

### Figuration picker

The settings sheet lists the figurations of the **active set** (the list swaps
with the Ottave switch) and lets each one be enabled/disabled. Generation draws
only from the enabled subset (falling back to the whole set if none are
enabled). Enabled state is tracked per set in the controller.

### Sound + metronome

* **Sound selector** (the whole selector): **Beatter** — plays the movimento's
  own WAV; **Silenzio** — plays nothing, timeline/highlight advance identically.
  The old Drum / Snare / Stick options are gone.
* **Metronome** — an independent on/off switch. When on, a click plays on every
  beat of the grid (accent every 4th), layered over whatever the sound selector
  is doing. It rides the same drift-free scheduler as the figurations.

---

## 2. How figurations are loaded

Assets live under `assets/application/<category>/`:

```
assets/application/
  1_4/  1_4 WAV/*.wav          FIGURAZIONI 1_4/*.png     (MIDI/NO BACKGROUND: not bundled)
  2_4/  2_4 WAV/*.wav          FIGURAZIONI 2_4/*.png
  4_4/  4_4 WAV/*.wav          FIGURAZIONI 4_4/*.png
  OTTAVI/ OTTAVI WAV/*.wav     FIGURAZIONI OTTAVI/*.png
```

`FigurationLibrary.load()` reads the runtime `AssetManifest` and keeps every key
matching `assets/application/<folder>/<folder> WAV/<id>.wav`. For each match it
derives:

* **category** from the folder (`1_4` → quarter, …, `OTTAVI` → eighths);
* **wavAsset** = the manifest key minus the `assets/` prefix (what
  `AssetSource` expects), e.g. `application/4_4/4_4 WAV/N1_1.wav`;
* **imageAsset** by stripping the WAV variant suffix (`N1_1` → `N1`,
  `O26_2` → `O26`) and pointing at the matching `FIGURAZIONI` PNG.

Because the index is built from the **WAV files that actually ship**, missing
renderings (`M2`, `O8`, …) are simply absent — never silent tiles. Dropping a
new WAV into a category folder makes it available with no code change.

### Duration model (and why MIDI is not bundled)

Each figuration's musical length comes from its **category**, not from the WAV
length (which is only the sound's decay). This was verified against the bundled
MIDI:

* `2_4` → all **2.0** beats, `4_4` → all **4.0**, `OTTAVI` → all **1.5**.
* `1_4`'s MIDI is unreliable (reports 4–37 beats), so `1_4` = **1.0** by folder.

Since durations are uniform per category, they are encoded as constants on
`FigurationCategory`. MIDI is therefore **not bundled or parsed** — this is both
simpler and consistent with "don't implement MIDI yet." The extension point is
in place (see §6) if per-figuration durations are ever needed.

---

## 3. Preload and cache

`FigurationAudioCache` is the performance core.

* **Preload once.** At Flow Mode entry, `preload()` creates **one
  `AudioPlayer` per WAV** and calls `setSource(AssetSource(...))` a single time.
  All disk reads and decoder setup happen here, up front (in parallel).
* **Fire with no allocation.** During playback, `trigger(wav)` only does
  `stop()` + `resume()` on an already-prepared player — no asset lookup, no disk
  read, no per-beat object allocation on the audio path.
* **Voices per asset.** Figurations load with one voice each: consecutive cells
  are almost always different files, so their decays overlap on separate
  players. The **metronome** is re-triggered every beat, so it loads with a
  small pool (3 voices) that `trigger` round-robins across — otherwise rapid
  `stop()`+`resume()` on a single player drops clicks.
* **Resilient.** Per-file load failures are swallowed, so one bad asset never
  blocks the rest and headless test environments still complete.

Loading is decoupled from display: the controller shows the first generated
sequence immediately, then warms the cache in the background (`isAudioReady`).

---

## 4. Timing precision (no drift, no gaps)

`AudioScheduler` is a small, audio-agnostic sequencer. It owns a monotonic
`Stopwatch` and a sorted list of **absolute beat offsets**, and invokes
`onEvent(index)` the instant each offset comes due.

Guarantees:

* **5 ms polling** → sub-frame trigger accuracy.
* **Absolute-beat scheduling.** Each poll converts elapsed wall-clock time to a
  beat position using the **live BPM**, so tempo changes apply on the next tick.
* **Drift-free looping.** At the loop point the origin is advanced by exactly one
  cycle length in milliseconds (`_loopStartMs += totalBeats * msPerBeat`); the
  stopwatch is **never reset**, so no rounding error accumulates over long
  sessions. Events already due at the top of the new cycle fire immediately, so
  there is no one-tick gap between cycles.
* **Seamless regeneration.** `updateTimeline()` swaps the timeline while running
  and re-seeks the event cursor to the current beat, so a regenerated sequence
  slots in without a stumble. Auto-variation goes further: `swapOne()` replaces a
  single figuration **within the same category**, leaving all offsets and the
  total length unchanged — nothing to reschedule.

### Tempo vs. the 70 BPM WAVs

Every WAV is rendered at a fixed reference tempo of **70 BPM**
(`kFigurationReferenceBpm`), encoded in its SMPTE marker. The tempo slider
defaults to **70 BPM** and is limited to **40–180 BPM**:

* At **70 BPM** the WAVs concatenate perfectly — a true seamless sequencer.
* **Away from 70** the grid stays exact and never drifts; the WAV audio simply
  overlaps a little (faster) or leaves a small gap (slower), absorbed by the
  per-WAV voices. Real re-tempo of the audio needs time-stretching (see §6).

---

## 5. What changed in Flow Mode

* Flow Mode now uses `FlowPlaybackController` instead of `RhythmPlaybackService`.
* Removed from Flow: the `assets/icon/` screenshot-driven slot generation, the
  filename-`if/else` `RhythmSlot.fromAsset`, and the Drum/Snare/Stick instrument
  dropdown.
* Added: the **Ottave** switch, the **Beatter / Silenzio** selector, the
  **metronome** on/off switch, and the per-set **figuration picker**.
* Tempo defaults to **70 BPM**, limited to **40–180**. The movimento counter
  reads the currently playing tile (1…N).
* Dead code cleanup (nothing else referenced these): `RhythmSlot` removed from
  `models/rhythm_element.dart`; `prepareSlotPlayback` / `updateSlotsSeamlessly`
  removed from `RhythmPlaybackService`. The service's shared timeline/metronome
  logic used by other modes is unchanged.
* Tiles now render the real figuration notation PNGs in a `Wrap`, so any number
  of figurations lays out without overflow.

---

## 6. Planned extensions (already accounted for)

The layer was shaped so these land without rework:

* **MIDI** — `Figuration` can carry a per-figuration duration/onset map parsed
  from the `.mid` files at preload; only the loader changes, not the model or the
  scheduler. (Deliberately not built yet.)
* **New figurations / durations** — add a value to `FigurationCategory` (folder +
  beats) and drop the WAVs in; the library, generator and cache pick them up
  automatically. Triplets, sixteenths, other meters fit the same way.
* **Time-stretching** — to make BPM re-time the WAVs, the cache/scheduler gain a
  rate parameter; the timeline math is unaffected.
* **Sheet / Reading / Polyrhythm / Exercises** — `AudioScheduler` and
  `FigurationAudioCache` are UI- and mode-agnostic. A mode supplies its own
  timeline (from a score, a polygon, an exercise) and reuses the same drift-free
  clock and preloaded voices. `FlowSequenceGenerator` is the only Flow-specific
  piece.
