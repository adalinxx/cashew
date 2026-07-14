# Redesign series dependency

VolumeBroker is the first `VolumeStorer` consumer. Its companion PR accepts each
complete `SerializedVolume` directly and persists Volume roots independently.

This change is source-breaking for former lifecycle-based storage adapters. They
now implement one async `store(volume:)` method and no longer maintain traversal
scope, pending-buffer, flush, or abort state.
