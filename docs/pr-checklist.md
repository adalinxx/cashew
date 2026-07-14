# Volume storage review checklist

- [ ] Each `VolumeStorer` call receives one complete `SerializedVolume`.
- [ ] Missing or unresolved same-boundary Headers prevent emission.
- [ ] Nested Volume bytes are absent from the parent payload.
- [ ] Relationships between Volumes remain encoded only in the DAG.
- [ ] Empty, targeted, and recursive plans cross the intended boundaries.
- [ ] Storage and resolution interpret structural and compressed-radix paths equally.
- [ ] Unselected unresolved Volumes are allowed; selected unresolved Volumes fail.
- [ ] A selected child failure leaves the already-stored parent available.
- [ ] Encrypted entries use `KeyProvider` when the `VolumeStorer` also conforms.
- [ ] No application-specific retention or completeness policy enters Cashew.
