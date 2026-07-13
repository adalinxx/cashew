# Foundational architecture alignment

This change aligns Cashew's generic storage traversal with the Lattice foundational law that a stored Volume is one complete availability unit.

## Structural contract

- `enterVolume(rootCID:)` opens one traversal scope.
- The Volume root, every ordinary owned child returned by `Node.properties()`, and every Header-valued `RadixNode.value` are members of that scope.
- A property named by `Node.properties()` must resolve to a Header through `get(property:)`; structural disagreement fails closed.
- An unresolved ordinary non-Volume child is an incomplete owned traversal and fails closed.
- Every owned nested Volume emits `includeNestedVolume(rootCID:)`, regardless of whether the child is locally materialized.
- `includeNestedVolume` records ownership only. It does not assert that the nested Volume's bytes are available.
- The enclosing Volume exits before any materialized nested Volumes are stored independently.
- Failure to store a nested Volume leaves the already-complete enclosing Volume published and the child unavailable.
- `abortVolume(rootCID:)` discards failed open-scope state and must be idempotent, including cleanup after a partially failing `enterVolume`.
- `contains(rawCid:)` may optimize ordinary content storage, but cannot suppress membership recording during a Volume-aware traversal.
- Header and Volume roots share one canonical serialization/encryption path.

This remains generic. Cashew does not decide application workflow completeness, storage retention policy, peer selection, consensus validity, or which nested Volumes a particular operation requires. It preserves the ownership semantics already expressed by existing recursive storage, while `Volume` defines availability boundaries and `Reference` remains outside child traversal.

## Correctness evidence

`VolumeStoreLifecycleTests` covers:

- successful root publication;
- root-store and partially-open-entry failure cleanup;
- unresolved root and ordinary owned-child rejection;
- inconsistent declared-child rejection;
- hydration-independent nested ownership edges;
- unresolved nested-Volume independence;
- child-store failure after parent publication;
- membership recording when bytes already exist;
- preservation of the ordinary non-Volume deduplication fast path;
- encrypted root CID/decryption round-trip;
- descendant encryption and serialization failures;
- mismatched exit and idempotent abort cleanup.

`VolumeMerkleDictionaryTests` uses the same explicit edge and stack-balanced lifecycle as the production VolumeBroker conformer.

The companion VolumeBroker change remains responsible for atomic durable storage, content-byte deduplication, and persistence of the explicit parent-to-child Volume edge without conflating that edge with child-byte availability.
