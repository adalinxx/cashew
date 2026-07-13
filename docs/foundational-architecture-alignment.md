# Foundational architecture alignment

This change aligns Cashew's generic storage traversal with the Lattice foundational law that a stored Volume is one complete availability unit.

## Structural contract

- `enterVolume(rootCID:)` opens one traversal scope.
- The Volume root, every ordinary child returned by `Node.properties()`, and every Header-valued `RadixNode.value` are members of that scope.
- A property named by `Node.properties()` must resolve to a Header through `get(property:)`; structural disagreement fails closed.
- An unresolved ordinary non-Volume child makes that Volume incomplete and fails closed.
- A nested Volume starts a separate availability unit. Its relationship to the enclosing node remains encoded in the content-addressed data structure and is not duplicated as storage metadata.
- An unresolved nested Volume is not stored and does not make the enclosing Volume incomplete.
- The enclosing Volume exits before any materialized nested Volumes are stored independently.
- Failure to store a nested Volume leaves the already-complete enclosing Volume published and the child unavailable.
- `abortVolume(rootCID:)` discards failed open-scope state and must be idempotent, including cleanup after a partially failing `enterVolume`.
- `contains(rawCid:)` may optimize ordinary content storage, but cannot suppress membership recording during a Volume-aware traversal.
- Header and Volume roots share one canonical serialization/encryption path.

This remains generic. Cashew does not decide application workflow completeness, storage retention policy, peer selection, consensus validity, or which nested Volumes a particular operation requires. `Volume` defines availability boundaries, while relationships between those boundaries remain in the typed DAG and `Reference` remains outside child traversal.

## Correctness evidence

`VolumeStoreLifecycleTests` covers:

- successful root publication;
- root-store and partially-open-entry failure cleanup;
- unresolved root and ordinary same-boundary child rejection;
- inconsistent declared-child rejection;
- unresolved nested-Volume independence;
- separate storage of materialized nested Volumes;
- child-store failure after parent publication;
- membership recording when bytes already exist;
- preservation of the ordinary non-Volume deduplication fast path;
- encrypted root CID/decryption round-trip;
- descendant encryption and serialization failures;
- mismatched exit and idempotent abort cleanup.

`VolumeMerkleDictionaryTests` uses the same independent, stack-balanced lifecycle as the production VolumeBroker conformer.

The companion VolumeBroker change remains responsible for atomic durable storage and content-byte deduplication within each independent Volume.
