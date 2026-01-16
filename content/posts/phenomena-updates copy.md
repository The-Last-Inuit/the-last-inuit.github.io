+++
title = "röyksopp | Update"
date = 2026-01-17
+++

It started as an OTP-flavored actor runtime with a toy TCP mesh, and now it has a minimal blockchain node layered on top.

## TL;DR

- Added a minimal blockchain pipeline with persistence, mempool rules, and round-robin consensus.
- Introduced compact block propagation and batched sync.
- Added CLI tools and scripts to spin up a local cluster and play with it.
- Expanded docs, tests, and fuzzing so the system is easier to reason about.

## What changed

### Persistence and recovery

- **BlockStore** is still append-only, but the **StateStore** now uses snapshot + WAL (write-ahead log).
- On startup, state can **recover by replaying the WAL** and verifying against the block store tip.
- This gives a simple durability story without a full DB.

### Mempool rules

- Mempool now validates txs:
  - **size limit**
  - **minimum fee**
  - **duplicate detection**
- Ordering is **fee-first** when assembling blocks.
- `Tx` now includes a `fee` field and stable `id` hash.

### Consensus hardening

- Consensus is still **round-robin leader**, but now includes **view timeouts**.
- A node bumps its **view** when it times out and broadcasts a `ViewChange`.
- Blocks include the **view** in the header.

### Block propagation

- Added **compact block announcements**:
  - Nodes announce headers + tx IDs.
  - Peers reconstruct if they already have the txs.
  - Otherwise they fetch the full block by height.
- Added **batched block sync** to reduce RPC chatter.

## Tooling and scripts

### CLI binaries

- `royksopp` - run a node from config.
- `royksopp_keys` - generate/read keypair and print pubkey hex.
- `royksopp_play` - interactive playground (local or attached).

### Scripts

- `scripts/run_nodes.sh` - spin up N nodes and write configs/logs.
- `scripts/play.sh` - interactive client (in-process by default).
- `scripts/demo.sh` - full demo: start nodes + attach client.

### Make targets

```bash
make demo      # nodes + interactive client
make play      # in-process playground
make nodes     # run nodes only
make test      # all tests
make clippy    # lint
```

## API usage

In-process submission:

```rust
let tx = Tx { key: b"foo".to_vec(), value: b"bar".to_vec(), fee: 1 };
runtime.chain.submit_tx(tx).await?;
```

RPC submission:

```rust
let req = ChainRequest::SubmitTx { tx };
let bytes = bincode::serialize(&req)?;
let resp_bytes = net.request(peer_id, "chain", bytes, Duration::from_secs(2)).await?;
```

## Wire protocol (short version)

- All frames are **length-delimited** and **bincode-encoded**.
- Envelope: `version`, `chain_id`, `msg_type`, `request_id`, `payload`.
- `Hello` includes **ed25519 signature** over version/chain_id/id/listen/pubkey.
- Chain RPCs:
  - `GetTip`, `GetBlock`, `GetBlocks`, `SubmitTx`

## Documentation refresh

`README.md` now includes:
- Architecture overview
- Wire protocol details
- Config schema and defaults
- API examples
- Scripts and CLI usage

## Tradeoffs / limitations

- No tx signatures or account model.
- No fork choice beyond round-robin + view timeouts.
- Mempool is in-memory only.
- Transport is authenticated but **not encrypted**.

## If you want to try it

The easiest path:

```bash
make demo
```

Then use the interactive prompt:

```
key=value [fee]
tip
exit
```

## What I want to do next

- Persistent mempool + eviction
- Snapshot/restore tools
- Peer scoring + backoff
- Transport encryption + message signing
