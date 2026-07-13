# Correctness invariants

## CASHEW-VOLUME-001 — successful traversal closes its scope

A successful `Volume.storeRecursively` sequence enters, stores, and exits the matching root exactly once.

## CASHEW-VOLUME-002 — failed traversal aborts its scope

When storage or descendant traversal throws, `abortVolume(rootCID:)` is invoked and the matching exit is not.

## CASHEW-VOLUME-003 — cashew remains semantics-generic

The lifecycle communicates traversal success or failure only. It does not decide application workflow completeness, retention, validity, or canonicity.

Established by: `VolumeStoreLifecycleTests`.
