+++
title = "sääl | core polish + proto + in-memory store"
date = 2026-01-10
+++

Quick engineering log for sääl. The current round of changes is mostly about 
tightening the core types, making canonical encoding boringly deterministic, 
and putting a thin protocol + storage layer around it so the rest of the 
system has something real to plug into.

**Updates**

`saal-core` got a few practical fixes and clarifications:

- **Canonical CBOR is now explicit**: serialization goes through 
  `serde_cbor::value::to_value` so map key ordering is deterministic before 
  hashing.
- **Signature plumbing cleaned up**: the Ed25519 `Signer` trait is in scope, 
  and signature decoding uses explicit length errors instead of ambiguous `?` 
  behavior.
- **Dependency hygiene**: `serde_bytes` is in place anywhere we use 
  `#[serde(with = "serde_bytes")]` for byte arrays.

Net result: `ObjectId` hashing is stable, and the sign/verify path is a little 
harder to trip over.

**Protocol surface (saal-proto)**

I added a small `saal-proto` crate that just defines message shapes and 
CBOR codecs:

- `GetObject` request/response (fetch by `ObjectId`).
- `GetAuthorLog` request/response (seq-based author log paging).
- A tiny `PingPolicy` message for capability negotiation.

Everything is encoded/decoded via canonical CBOR so the wire format stays 
consistent across implementations.

**In-memory store (saal-store-mem)**

There’s now a minimal in-memory store to make the protocol testable:

- Objects are stored as canonical CBOR bytes of signed `Object`s.
- Author logs are indexed by seq using a `BTreeMap`, so paging is 
  deterministic.
- Tests exercise round-trip decode + signature verification on stored 
  entries.

It’s intentionally simple, but it’s already enough to test end-to-end flows 
without a real database.

**Tooling cleanup**

I dropped in a basic `Makefile` and `.gitignore` so the workflow is less 
repetitive, plus a few small dependency nudges to keep the workspace 
compiling cleanly.

**Next**

- A storage trait so the in-memory store can be swapped out cleanly.
- Wire-level integration tests with CBOR fixtures.
- A tiny CLI for creating and inspecting objects during development.
