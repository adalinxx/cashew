# Foundational architecture alignment

This change aligns cashew's generic storage traversal with the Lattice foundational law that a stored Volume is one complete availability unit.

## Structural contract

- `enterVolume(rootCID:)` opens one traversal scope.
- The Volume root and every materialized ordinary child returned by `Node.properties()` are members of that scope.
- An unresolved ordinary non-Volume child is an incomplete owned traversal and fails closed.
- A nested Volume is a separate availability unit. Its CID is already committed by the enclosing node, so an unresolved nested Volume may remain absent without making the enclosing Volume partial.
- `exitVolume(rootCID:)` publishes a scope only after the complete owned boundary was traversed.
- `abortVolume(rootCID:)` discards failed scope state and must be idempotent.
- `contains(rawCid:)` may optimize ordinary content storage, but cannot suppress membership recording during a Volume-aware traversal.

This remains generic. Cashew does not decide application workflow completeness, storage retention, peer selection, or consensus validity. It enforces only the ownership and boundary semantics already expressed by `Node.properties()` and `Volume`.

## Correctness evidence

`VolumeStoreLifecycleTests` covers:

- successful root publication;
- root-store failure and cleanup;
- unresolved root rejection;
- unresolved owned-child rejection;
- unresolved nested-Volume independence;
- membership recording when bytes already exist;
- preservation of the ordinary non-Volume deduplication fast path;
- completed nested child plus later outer failure;
- descendant encryption and serialization failures;
- mismatched exit and idempotent abort cleanup.

The companion VolumeBroker change is the first production conformer. It remains responsible for atomic durable storage and for deduplicating content bytes without losing per-Volume membership.
