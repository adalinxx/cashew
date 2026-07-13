# Volume lifecycle review checklist

- [ ] Every `enterVolume` has a successful `exitVolume` or a failure `abortVolume`.
- [ ] Failed traversal cannot publish an incomplete scope.
- [ ] Nested Volumes remain independent availability units.
- [ ] No application-specific completeness policy enters cashew.
- [ ] Consumer conformers are migrated explicitly; no silent default lifecycle behavior remains.
