# Foundational architecture alignment

This change aligns cashew's generic Volume traversal with the Lattice foundational law that a stored Volume is an atomic availability unit.

## Contract

- `enterVolume(rootCID:)` opens one traversal scope.
- `exitVolume(rootCID:)` publishes that scope only after successful traversal.
- `abortVolume(rootCID:)` discards the active scope when traversal fails.
- A failed traversal must never leave bytes that a downstream storer can later publish as a complete Volume.

This remains generic. cashew does not decide application workflow completeness, storage retention, peer selection, or consensus validity. Nested Volumes remain independent availability units.

## Correctness evidence

`VolumeStoreLifecycleTests` proves both sides of the lifecycle:

- successful traversal reaches exactly one matching exit;
- failed storage aborts the scope and never publishes it.

The companion VolumeBroker change implements the lifecycle with fail-closed scope accounting and atomic durable writes.
