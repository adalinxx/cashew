# Redesign series dependency

VolumeBroker is the first consumer of this new lifecycle. Its companion PR implements `abortVolume`, rejects incomplete scopes, and atomically persists only complete validated Volumes.

This cashew change is source-breaking for `VolumeAwareStorer` conformers by design: silent default lifecycle behavior cannot enforce the complete-Volume invariant. The coordinated consumer branch and full-stack node branch provide migration and integration coverage.
