# Correctness invariants

## CASHEW-VOLUME-001 — successful traversal closes its scope

A successful `Volume.storeRecursively` sequence enters, stores the complete ordinary boundary, and exits the matching root exactly once.

## CASHEW-VOLUME-002 — failed traversal aborts its scope

When entry, storage, structural traversal, or exit throws before publication, `abortVolume(rootCID:)` is invoked and the matching scope is not published.

## CASHEW-VOLUME-003 — unresolved same-boundary nodes fail closed

An ordinary non-Volume header returned by `Node.properties()`, or stored as a Header-valued `RadixNode.value`, is an entry in the current Volume boundary. If its node is unresolved during a Volume-aware traversal, the traversal throws and the enclosing Volume aborts.

## CASHEW-VOLUME-004 — declared membership is internally consistent

When `Node.properties()` names a child, `get(property:)` must return its Header. A complete-Volume traversal fails closed with `DataErrors.missingDeclaredChild` rather than silently omitting an inconsistent declared child.

## CASHEW-VOLUME-005 — nested-Volume relationships remain in content

The enclosing node already commits to each nested Volume CID. Storage does not duplicate those relationships as separate metadata or infer retention policy from them.

## CASHEW-VOLUME-006 — nested Volumes are independent availability units

The enclosing Volume exits before materialized nested Volumes are stored. Failure to store a nested Volume does not retroactively unpublish the already-complete enclosing Volume; the child simply remains unavailable.

## CASHEW-VOLUME-007 — content deduplication does not erase membership

During a Volume-aware traversal, every materialized ordinary node in the boundary reaches `store(rawCid:data:)` even when `contains(rawCid:)` reports that its bytes already exist. The storer may deduplicate bytes internally, but must record membership in every completed boundary that contains the CID.

## CASHEW-VOLUME-008 — root publication requires a materialized root

Calling `storeRecursively` directly on an unresolved Volume root fails with `DataErrors.nodeNotAvailable` before opening a scope.

## CASHEW-VOLUME-009 — entry cleanup and abort are idempotent

`enterVolume` is inside the protected lifecycle. If it allocates a scope and then throws, `abortVolume(rootCID:)` cleans it. Abort is non-throwing and may be repeated without publishing or resurrecting failed state.

## CASHEW-VOLUME-010 — encrypted storage preserves content identity

Header and Volume storage share one serialization/encryption implementation. Bytes emitted for an encrypted Volume root must hash to its declared CID and decrypt to its original node.

## CASHEW-VOLUME-011 — cashew remains semantics-generic

The lifecycle enforces only structural membership inside one Volume boundary and boundary completion. It does not decide application workflow completeness, retention policy, validity, canonicity, or which nested Volumes an application operation requires.

Established by: `VolumeStoreLifecycleTests` and `VolumeMerkleDictionaryTests`.
