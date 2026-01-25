+++
title = "steer"
date = 2026-01-18
+++

[Steer](https://app.radicle.xyz/nodes/seed.radicle.garden/rad:z4WueZLqUwwjNxZDd3jQTa7XoNmNL) is a small but opinionated experiment in local‑first collaboration. 
It pairs a Dioxus LiveView front end with a libp2p-powered backend so you can 
ideate even when Wi‑Fi is flaky, then sync when peers appear. This post walks 
through how it works, how to run it, and what to demo.

**What Steer Does**
- Local-first: you can read/write ideas and comments without a server 
  round-trip; networking is additive, not required.
- P2P sync: libp2p gossips events (ideas, votes, moderation actions) 
  between peers.
- Moderation: capabilities, rate limits, and proof checks gate inbound 
  events.
- Offline shell: a minimal service worker caches the app shell and 
  assets (`/offline.html` keeps the UI available).

**Architecture Snapshot**
- Rust + Axum host a Dioxus LiveView app at `/` and a WebSocket endpoint 
  at `/ws`.
- The derived application state is rebuilt from an append-only event log 
  (`steer-core` + `steer-net`).
- Static assets live under `crates/steer-app/static` (`ë.css`, `ë.ui.js`, 
  icons, offline page) and are served directly by the Axum router.
- The service worker pre-caches the shell and icons; it stores fetched 
  requests into a simple cache (`steer-cache-v2`).

**Running It Locally**

Prereqs: Rust (stable), Git. No external DB or brokers required.

```bash
git clone https://github.com/your-org/steer.git
cd steer
cargo run --package steer -- \
  --http 127.0.0.1:8080 \
  --store memory
```

Then open `http://127.0.0.1:8080/` in your browser. The UI loads `ë.css` 
for styling and connects to `/ws` for live updates.

**File-backed store**

Persist the log to disk and reuse it across restarts:

```bash
cargo run --package steer -- \
  --store file \
  --store-path ./data/steer.log
```

**P2P toggles**
- `--no-p2p`: run in fully local mode.
- `--listen /ip4/0.0.0.0/tcp/0`: add more listen addresses.
- `--dial /ip4/…/tcp/…/p2p/<peerid>`: connect to a remote peer.
- `--wan-profile`: enable relay + AutoNAT, disable mDNS for WAN-friendly
  operation.

**Moderation knobs**
- `--require-pow-bits 8`: inbound envelopes must prove PoW with 8 leading 
  zero bits.
- `--attach-pow-bits 8`: attach PoW to outbound envelopes.
- `--allow-invite <token>` / `--invite-token <token>`: require and attach 
  invite tokens.
- `--cap-subject <pubkey>`: embed your capability subject in moderation events.

**Demo Script**
1. **Create ideas**: Propose a few ideas; note the single-line inputs and dotted 
  containers. Show offline shell still working if you flip Chrome to offline 
  (cached by SW).
2. **Voting + comments**: Open comments, add replies, collapse threads. Observe 
  live updates across two browser tabs (they share the same WebSocket and state).
3. **Moderation actions**: Hide an event by ID, label it, then toggle "strict mode"
  to hide unapproved content. Grant/Revoke capabilities to a subject and see labels 
  appear.
4. **Checkpoint/export**: Click “Checkpoint now” to publish a checkpoint event, 
  then download `/export` and re-import it to show idempotent ingestion.
5. **P2P peek** (optional with two nodes): Run a second instance with `--dial` to 
  the first; add ideas on one node and watch them appear on the other.

**Notable Files**
- `crates/steer-app/src/main.rs`: Axum router, service worker payload, static 
  asset routes.
- `crates/steer-app/src/ui.rs`: Dioxus LiveView UI; references `ë.css` for the 
  shell and keeps small bridge styles for app-specific classes.
- `crates/steer-app/static/ë.css`: Design system (sharp, minimal, grid-aligned).
- `crates/steer-app/static/ë.ui.js`: Minimal JS behaviors (modals, toasts, 
  cmdk, validation, pagination).
- `crates/steer-core`, `crates/steer-net`: Event model and networking.

**Operational Notes**
- Service worker cache name is `steer-cache-v2`; bump it when adding static 
  assets so clients refresh.
- The UI is LiveView-driven; no SPA bundle build step is required.
- If you ship binaries, include the `static/` assets alongside for the routes 
  to serve them.

**Closing Thoughts**
Steer’s focus is ergonomics under bad networks: the UI stays responsive with or 
without peers, and synchronization is a best-effort background concern. The 
combination of Dioxus LiveView and libp2p keeps the stack lean while still 
giving you real-time collaboration and offline resilience.
