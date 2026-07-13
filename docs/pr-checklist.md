# Volume lifecycle review checklist

- [ ] Every `enterVolume` has a successful `exitVolume` or a failure `abortVolume`.
- [ ] An unresolved Volume root cannot be published.
- [ ] Every unresolved ordinary child returned by `Node.properties()` fails a Volume-aware traversal.
- [ ] Unresolved nested Volumes remain independent availability units and do not make the enclosing Volume partial.
- [ ] Relationships between Volume roots remain encoded in the DAG and are not duplicated as storage metadata.
- [ ] `contains(rawCid:)` cannot suppress membership recording inside an open Volume scope.
- [ ] Descendant storage, serialization, encryption, and exit failures abort the enclosing incomplete scope.
- [ ] `abortVolume(rootCID:)` cleanup is idempotent.
- [ ] Direct ordinary Header storage retains its existing best-effort and content-deduplication behavior for every Storer.
- [ ] No application-specific completeness policy enters cashew.
- [ ] Consumer conformers are migrated explicitly; no silent default lifecycle behavior remains.
