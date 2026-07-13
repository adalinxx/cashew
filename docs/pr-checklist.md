# Volume lifecycle review checklist

- [ ] Every `enterVolume` has a successful `exitVolume` or a failure `abortVolume`.
- [ ] An unresolved Volume root cannot be published.
- [ ] Every unresolved ordinary child returned by `Node.properties()` fails a Volume-aware traversal.
- [ ] Unresolved nested Volumes remain independent availability units and do not make the enclosing Volume partial.
- [ ] `contains(rawCid:)` cannot suppress membership recording inside an open Volume scope.
- [ ] Descendant storage, serialization, encryption, and exit failures abort the enclosing incomplete scope.
- [ ] `abortVolume(rootCID:)` cleanup is idempotent.
- [ ] Plain non-Volume Storers retain their existing content-deduplication behavior.
- [ ] No application-specific completeness policy enters cashew.
- [ ] Consumer conformers are migrated explicitly; no silent default lifecycle behavior remains.
