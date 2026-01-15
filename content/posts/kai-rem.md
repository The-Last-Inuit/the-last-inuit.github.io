+++
title = "kai-rem"
date = 2026-01-12
+++

![solënna](/img/kai-rem.png)

Lately I have been working on `kai-rem`, a realtime synth engine with a minimalist UI. The goal this week: add more sound engines, bolt on per-channel FX, and keep the interface simple enough to play without a manual.

Below is a quick, casual tour of what I changed, what worked, and a few gotchas I tripped over.

## The short version

- Added four engines: Supersaw, Ring Mod, Pluck (Karplus), Formant.
- Added per-channel FX modules: Drive, Delay, Chorus, Crush.
- Kept the UI compact: each channel gets a dropdown + amount slider.
- Routed keyboard input to the selected channel for easy auditioning.

The original synth had the basics (subtractive, wavetable, FM, pulse, noise). Great for testing, but I wanted more contrast:

- **Supersaw** for that classic wide, buzzy pad.
- **Ring Mod** for metallic and alien textures.
- **Pluck/Karplus** for instant “stringy” sounds.
- **Formant** to get vowel-ish timbres without a full filter bank.

The nice part about these is that they share a lot of code. Once the oscillator and filter plumbing is in place, new engines are mostly different signal paths.

## Per-channel FX

I went with a single FX slot per channel:

- **None**
- **Drive** (tanh saturation)
- **Delay** (simple feedback delay)
- **Chorus** (modulated delay line)
- **Crush** (bit + sample rate reduction)

## UI tweaks: small but important

The channel rack now shows:

- Track select, mute, solo
- Pan slider
- FX dropdown
- FX amount slider

I nudged the left column width to make room. The big UX improvement was simple: **keyboard notes now go to the selected channel**, not just channel 1. That makes testing per-channel FX feel immediate.

## Implementation notes

A few things worth mentioning:

- **Audio thread is sacred.** All UI updates go through a ring buffer to avoid blocking.
- **FX are in the mixer, not in the voice.** This keeps engines clean and lets FX act on the mixed channel signal.
- **Formant uses bandpass filters.** I added a bandpass output to the SVF for this.
- **Karplus gets a tiny delay buffer per voice.** Cheap, cheerful, and good enough for the vibe.

```bash
cargo run --release -- --poly 8 --mode supersaw --midi virtual
```

And yes, you can play notes with the keyboard when you do not have MIDI.
