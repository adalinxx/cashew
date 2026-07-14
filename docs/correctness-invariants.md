# Correctness invariants

## CASHEW-VOLUME-001 — only complete boundaries are emitted

Cashew serializes a Volume root and every same-boundary Header before making the
single `VolumeStorer.store(volume:)` call. Structural, serialization, and encryption
failures emit nothing for that boundary.

## CASHEW-VOLUME-002 — declared structure is consistent

Every property returned by `Node.properties()` must return a Header from
`get(property:)`. Otherwise storage fails with `DataErrors.missingDeclaredChild`.

## CASHEW-VOLUME-003 — Volume relationships stay in content

A parent payload contains the nested Volume CID only through the serialized parent
node. Storage does not duplicate parent/child relationships as metadata.

## CASHEW-VOLUME-004 — Volumes are independent

Nested Volume bytes are never members of the parent payload. The parent is stored
before a selected child, and a child failure does not undo the parent.

## CASHEW-VOLUME-005 — plans control traversal

The root is always stored. Empty paths stop there. `.targeted` stores the boundary
at a path, while `.recursive` also stores all materialized nested boundaries. The
path interpretation matches resolution, including compressed radix keys.

## CASHEW-VOLUME-006 — selection controls materialization requirements

An unresolved same-boundary Header always makes the current Volume incomplete. An
unresolved nested Volume is allowed when unselected and fails when selected.

## CASHEW-VOLUME-007 — encrypted storage preserves content identity

Bytes emitted for an encrypted Header hash to its declared CID and decrypt to the
original node when the `VolumeStorer` also conforms to `KeyProvider`.

## CASHEW-VOLUME-008 — policy remains outside Cashew

Cashew enforces boundary completeness and follows caller-provided paths. It does not
infer application retention, workflow completeness, validity, or canonicity.

Established by `StoragePlanTests` and `VolumeMerkleDictionaryTests`.
