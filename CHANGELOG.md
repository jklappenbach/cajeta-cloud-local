# Changelog

## 0.1.0 (unreleased)

- `FilesystemObjectStore`: cajeta-cloud's object-store port over a directory.
  One file a key with its metadata in a header, installed by temp-and-rename;
  percent-encoded segments; conditional writes, copy, range reads, listing
  identical to the memory driver's, multipart staged as files. Dev-grade,
  declared as `object.dev-grade`. Passes cajeta-cloud's ObjectStoreContract.
