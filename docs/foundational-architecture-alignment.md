# Foundational architecture alignment

Cashew treats each `Volume` as an independent availability boundary. The typed,
content-addressed DAG remains the sole source of relationships between Volumes.

## Storage contract

- Cashew fully serializes the selected Volume before calling `VolumeStorer`.
- Complete-boundary buffering uses temporary memory proportional to that boundary's
  serialized size; callers should choose smaller Volume boundaries when needed.
- `SerializedVolume.entries` contains the root, ordinary Header descendants, and
  Header-valued radix values up to the next Volume boundary.
- Every emitted entry is verified against its declared CID before persistence.
- Missing declared children or unresolved same-boundary Headers fail before a
  selected boundary is emitted, including children outside a targeted path.
- Nested Volumes are never included in the parent payload.
- The root Volume is always selected. `StorageStrategy.targeted` selects a nested
  boundary; `.recursive` selects that boundary and its materialized descendants.
- Storage paths use the same structural and compressed-radix traversal rules as
  resolution paths. A deep target selects the intervening Volume boundaries needed
  to reach it.
- An unselected unresolved Volume is valid. A selected unresolved Volume fails.
- The parent is persisted before selected children, so a child failure cannot make
  the already-complete parent partial.
- Multi-Volume plans are non-transactional. Completed ancestors remain stored after
  a descendant failure, and identical retries must be idempotent.
- Header and Volume roots share one canonical serialization and encryption path.
- A shared selected Volume is emitted once per operation, while distinct targeted
  subplans through it are all traversed.

Cashew does not infer retention, workflow completeness, peer selection, validity,
or canonicity. Applications choose storage and retention plans explicitly.

## Correctness evidence

`StoragePlanTests` covers boundary completeness, root-only and targeted storage,
recursive selection, traversal through ordinary Headers, unresolved children,
parent durability, CID verification, shared DAGs, encryption, and compressed-radix
path equivalence.

`VolumeMerkleDictionaryTests` verifies complete recursive round trips across a trie
whose internal links are all independent Volumes.
