# Correctness invariants

## CASHEW-VOLUME-001 — successful traversal closes its scope

A successful `Volume.storeRecursively` sequence enters, stores, and exits the matching root exactly once.

## CASHEW-VOLUME-002 — failed traversal aborts its scope

When storage or descendant traversal throws, `abortVolume(rootCID:)` is invoked and the matching exit is not published.

## CASHEW-VOLUME-003 — unresolved owned nodes fail closed

An ordinary non-Volume header returned by `Node.properties()` is owned by the current Volume boundary. If its node is unresolved during a Volume-aware traversal, the traversal throws and the enclosing Volume aborts.

## CASHEW-VOLUME-004 — nested Volumes are independent availability units

An unresolved nested Volume does not make the enclosing Volume partial. The enclosing node already commits to the nested Volume CID; the nested Volume is stored independently only when its own node is materialized.

## CASHEW-VOLUME-005 — content deduplication does not erase membership

During a Volume-aware traversal, every materialized owned node reaches `store(rawCid:data:)` even when `contains(rawCid:)` reports that its bytes already exist. The storer may deduplicate bytes internally, but must record membership in every completed boundary that owns the CID.

## CASHEW-VOLUME-006 — root publication requires a materialized root

Calling `storeRecursively` directly on an unresolved Volume root fails with `DataErrors.nodeNotAvailable` before opening a scope.

## CASHEW-VOLUME-007 — cleanup is idempotent

`abortVolume(rootCID:)` is non-throwing and may be repeated after nested cleanup without publishing or resurrecting a failed scope.

## CASHEW-VOLUME-008 — cashew remains semantics-generic

The lifecycle enforces only structural ownership and Volume-boundary completion. It does not decide application workflow completeness, retention, validity, canonicity, or which nested Volumes an application requires.

Established by: `VolumeStoreLifecycleTests`.
