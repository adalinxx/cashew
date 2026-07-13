# Review order

1. `VolumeAwareStorer.swift` lifecycle and membership contract.
2. `Header+store.swift` ordinary best-effort and content-deduplication behavior.
3. `Node+store.swift` same-boundary versus nested-Volume traversal.
4. `Volume+store.swift` root availability, encryption, and abort-on-error behavior.
5. `VolumeStoreLifecycleTests.swift` adversarial invariant evidence.
6. `VolumeMerkleDictionaryTests.swift` stack-balanced grouped-store integration fixture.
7. Companion VolumeBroker PR for the first production consumer.
