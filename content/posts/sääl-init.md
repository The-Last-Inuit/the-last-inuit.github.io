+++
title = "sääl | wiring up the core"
date = 2026-01-09
+++

Quick update on sääl’s engineering progress. I’ve been focused on getting the 
wire-level core in place first, so there’s a solid, deterministic foundation 
before anything network-y or storage-y lands.

**So far**

The repo now has a `saal-core` crate that’s basically the minimal 
spec-compliant kernel:

- **Canonical CBOR encoding** for unsigned objects so every node hashes the 
  same bytes.
- **ObjectId** as BLAKE3-256 over canonical CBOR of the unsigned envelope.
- **Ed25519 signatures** over the ObjectId, plus verification helpers.
- **Typed payloads** for the v0.1 wire spec: `Profile`, `Post`, `Reaction`, 
  `Follow`, `MediaBlob`, and `LogEntry`.
- **Tests** for deterministic IDs, sign/verify round-trips, and canonical 
  CBOR stability.

There’s also a draft wire spec (`wire-spec-v0.1.md`) in the repo that mirrors 
what the code is doing. The idea is to keep spec and code aligned while the
protocol is still fluid.

This is intentionally boring in a good way:

- **CBOR + canonical ordering** gives compact payloads and deterministic hashes. 
  No "same data, different bytes" surprises.
- **BLAKE3** is fast, well-designed, and gives a clean 32‑byte content ID.
- **Ed25519** is small, standard, and has good ecosystem support. Keys/signatures 
  stay compact, which matters for a p2p social protocol.
- **Explicit typed payloads** keep the wire schema readable and let me evolve 
  each object type without tangled dynamic maps everywhere.

The goal is to keep the cryptographic and serialization layer boringly correct. 
Everything else can be built on top of that with confidence.

**Current limits**

This is still v0.1 groundwork:

- No networking yet.
- No storage/indexing layer.
- No event log or feed processing pipeline.
- Just enough error handling to make the core usable without hiding failures.

That’s deliberate. I want the “object = canonical bytes + signature + 
deterministic ID” story to be rock-solid before the rest of the system starts 
depending on it.

**What’s next**

The next steps are about turning the core into something people can run 
and poke:

- **Storage + indexing**: persist objects, resolve by `ObjectId`, and build 
  lightweight views.
- **Networking protocol**: define how peers exchange objects and log entries 
  (likely built on libp2p).
- **Tooling**: a small CLI for creating/signing objects and inspecting CBOR 
  bytes.
- **Interoperability tests**: fixtures to prove that different implementations 
  serialize and hash the same bytes.
