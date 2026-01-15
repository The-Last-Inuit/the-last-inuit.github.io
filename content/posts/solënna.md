+++
title = "solënna"
date = 2026-01-14
+++

![solënna](/img/solënna.png)

# solënna: building a compact libp2p node for geotagged data

Here is a quick tour of the engineering choices behind solënna, a small libp2p node that publishes and browses signed, geotagged datapoints. My goals were simple: keep the stack small, ship a usable UI fast, and still survive on a public network without turning into a spam magnet.

## Problem framing

Location-based systems tend to be either centralized and easy, or decentralized and hard to operate. I wanted a node that felt like a single binary you can run on a laptop, but that still federates into a public P2P network without needing a dedicated ops stack. That led me to a few constraints:

- Storage needed to be local and simple.
- The UI had to ship with the node.
- The protocol had to verify authorship without central authority.
- The network had to defend itself from trivial write abuse.

## Architecture overview

At a high level, the node is a libp2p swarm loop plus a local SQLite store and an HTTP server. The [repo](https://app.radicle.xyz/nodes/seed.radicle.garden/rad:zhzsX3bknxQhN6wbTY2QoxPhGbzp) mirrors that split:

- `src/main.rs` is the swarm loop and CLI wiring.
- `src/protocol.rs` defines the signed object format and request/response types.
- `src/store.rs` implements persistence and geohash indexing.
- `src/http.rs` hosts both the LiveView UI and a JSON API.

Keeping it this way means one process, one data directory, and a much simpler mental model when you are debugging or deploying.

## Data model: signed objects with location metadata

I went with content-addressed objects that are signed by an author keypair. That gives me a few nice properties:

- IDs are derived from content, so the same object is globally stable.
- Signatures are verified at ingest, so provenance is embedded in the data itself.
- Objects can be replicated without a centralized database.

For the UI and API, the core field is location. A point maps to a geohash cell, which is a compact way to partition the earth into hierarchical grid buckets.

## Storage and queries: why geohash indexing works well here

The hot path is **what objects are in this viewport**. I did not want to pull in a heavy spatial index or do full-table scans with bounding boxes. Instead, the store indexes by geohash cell. The query becomes “enumerate the geohash cells that cover this viewport, then fetch objects per cell.”

It is a practical tradeoff:

- Geohash prefix lookups are cheap in SQLite.
- The index is stable and deterministic across nodes.
- It keeps the API simple (`GET /geocell`, `GET /viewport`).

It is not as precise as a proper spatial index, but it is more than enough for fast, map-like browsing.

## Anti-spam: PoW + rate limits instead of trust

Public P2P networks need backpressure. I did not want to build a full trust system, I just wanted to make abuse expensive. solënna uses a few levers in `src/anti_spam.rs`:

- Proof-of-work gating for write requests.
- Rate limits to dampen bursts.
- Optional allowlist for closed networks.

This is intentionally lightweight: it does not try to solve trust, only to make abuse expensive enough that it is not the default behavior.

## UI in the same process: Dioxus LiveView

The HTTP server embeds a Dioxus LiveView UI. I wanted the node to be useful immediately after `cargo run` without a separate frontend build or extra processes. That gives you:

- One binary that serves both UI and JSON API.
- Fewer deployment knobs and fewer moving parts.
- A quick feedback loop for experimenting with protocol changes.

For engineering velocity, this mattered more than having a fully decoupled frontend.

## Real-world networking: relay support

Most peers sit behind NAT, so Solenna ships a circuit-relay v2 binary (`src/bin/solenna-relay.rs`) and a relay manager (`src/relay_mgr.rs`). This solves the practical **I cannot accept inbound TCP** problem without needing to punch a dozen firewall holes. It also lets you run a public relay if you want to improve connectivity for the network.

## Operational shape

The project is designed to deploy simply:

- Docker and Docker Compose for fast local runs.
- systemd units for traditional hosts.
- Fly.io config for quick cloud launches.

The node's surface area is small: a libp2p TCP port and an HTTP port.

## What I would explore next

A few ideas are on the roadmap:

- Better edit conflict resolution for high-latency networks.
- Richer queries (tags, author trust, time windows).
- More granular spam controls for mixed public/private clusters.

## Closing thoughts

solënna is intentionally small (i dislike complexity as a justification for whatever). The goal was to prove out a minimal, usable P2P node that handles real network constraints and still feels like a developer-friendly tool. If you want to explore further, start in `src/store.rs` or `src/http.rs` and keep the loop tight: change a thing, run the node, open the UI, repeat.

For a quick run command and endpoint list, the README has the minimal setup.
